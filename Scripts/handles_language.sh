#!/bin/bash
# 终极解决方案 - 修复验证误报和文件缺失问题

# 动态获取架构
TARGET_ARCH=$(find "$GITHUB_WORKSPACE/wrt/staging_dir" -maxdepth 1 -type d -name "target-*" | head -n1 | xargs basename | sed 's/target-//')
SUBTARGET=$(find "$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH" -maxdepth 1 -type d -name "root-*" | head -n1 | xargs basename | sed 's/root-//')

# 扩展搜索路径（包含所有可能位置）
SEARCH_PATHS=(
  "$GITHUB_WORKSPACE/wrt/package"
  "$GITHUB_WORKSPACE/wrt/feeds/luci"
  "$GITHUB_WORKSPACE/wrt/feeds/packages"
  "$GITHUB_WORKSPACE/wrt/feeds/extra"
  "$GITHUB_WORKSPACE/wrt/feeds/luci/applications"
  "$GITHUB_WORKSPACE/wrt/feeds/luci/themes"
  "$GITHUB_WORKSPACE/wrt/feeds/packages/net"
  "$GITHUB_WORKSPACE/wrt/feeds/packages/utils"
  "$GITHUB_WORKSPACE/wrt/package/aliyundrive-webdav/openwrt"
  "$GITHUB_WORKSPACE/wrt/package/linkease"
)

# 关键目录配置
STAGING_I18N="$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH/root-$SUBTARGET/usr/lib/lua/luci/i18n"
LOG_DIR="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files"
mkdir -p "$STAGING_I18N" "$LOG_DIR"

# 主日志配置
MAIN_LOG="$LOG_DIR/language_package_final.log"
exec > >(tee -a "$MAIN_LOG") 2>&1

echo "===== 语言包处理开始 ====="
echo "目标架构: $TARGET_ARCH"
echo "子架构: $SUBTARGET"
echo "语言包目录: $STAGING_I18N"

# 工具检查
type po2lmo >/dev/null 2>&1 || { echo "错误：po2lmo未安装，请执行: sudo apt install po4a"; exit 1; }

# 核心函数：生成正确的.lmo文件名
get_lmo_name() {
  local plugin=$1
  # 转换规则：
  # luci-app-xxx → xxx.zh-cn.lmo
  # luci-theme-yyy → yyy.zh-cn.lmo
  echo "${plugin#luci-*}" | sed -E 's/^(app|theme|lib)-//'
}

# 增强版插件查找（支持多级目录和别名）
find_plugin_dir() {
  local plugin=$1
  local search_name="${plugin#luci-}"
  
  for path in "${SEARCH_PATHS[@]}"; do
    # 递归查找匹配插件名的目录（支持子目录）
    found=$(find "$path" -type d -iregex ".*/${plugin}\(-[a-z0-9]+)*" -print -quit)
    [ -n "$found" ] && echo "$found" && return 0
  done
  return 1
}

# 智能po文件查找（支持多层级结构）
find_po_file() {
  local dir=$1
  # 查找优先级：zh-cn > zh_Hans > 任意位置
  local po_file=$(find "$dir" -type f \( -path "*/po/zh-cn/*.po" -o -path "*/po/zh_Hans/*.po" \) -print -quit)
  [ -z "$po_file" ] && po_file=$(find "$dir" -type f \( -path "*/i18n/*.po" -o -path "*/po/*.po" \) -print -quit)
  echo "$po_file"
}

# 主处理流程
process_plugins() {
  echo "===== 开始处理插件 ====="
  
  for plugin in $WRT_LIST; do
    lmo_name=$(get_lmo_name "$plugin")
    lmo_file="$STAGING_I18N/${lmo_name}.zh-cn.lmo"
    
    # 跳过已存在的语言包
    [ -f "$lmo_file" ] && continue
    
    # 查找插件目录
    if ! plugin_dir=$(find_plugin_dir "$plugin"); then
      echo "[警告] 插件目录未找到: $plugin"
      continue
    fi

    # 查找po文件
    if ! po_file=$(find_po_file "$plugin_dir"); then
      echo "[跳过] 无翻译文件: $plugin (路径: $plugin_dir)"
      continue
    fi

    # 转换语言包
    if [ -f "$po_file" ]; then
      if po2lmo "$po_file" "$lmo_file"; then
        echo "[成功] 生成: $lmo_file (来源: $po_file)"
      else
        echo "[错误] 转换失败: $po_file → $lmo_file"
        rm -f "$lmo_file" 2>/dev/null
      fi
    else
      echo "[错误] .po文件不存在: $plugin_dir"
    fi
  done
}

# 精确验证（区分无翻译和转换失败）
validate_results() {
  echo "===== 验证结果 ====="
  local all_success=true

  for plugin in $WRT_LIST; do
    lmo_name=$(get_lmo_name "$plugin")
    lmo_file="$STAGING_I18N/${lmo_name}.zh-cn.lmo"
    
    # 查找插件目录
    if plugin_dir=$(find_plugin_dir "$plugin"); then
      # 检查是否存在po文件
      if po_file=$(find_po_file "$plugin_dir"); then
        if [ -f "$lmo_file" ]; then
          echo "[通过] $plugin → $(basename "$lmo_file")"
        else
          echo "[失败] 缺失语言包: $plugin (应存在: ${lmo_name}.zh-cn.lmo)"
          all_success=false
        fi
      else
        echo "[跳过] 无翻译文件: $plugin"
      fi
    else
      echo "[警告] 插件目录未找到: $plugin"
    fi
  done

  $all_success && echo "===== 所有语言包验证通过 =====" || echo "===== 存在缺失的语言包 ====="
}

# 执行流程
process_plugins
validate_results

# 生成清单文件（用于调试）
find "$STAGING_I18N" -name "*.zh-cn.lmo" | sort > "$LOG_DIR/generated_lmo_files.txt"
echo "===== 已生成的语言包清单 ====="
cat "$LOG_DIR/generated_lmo_files.txt"
