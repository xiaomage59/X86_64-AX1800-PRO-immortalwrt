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
  "$GITHUB_WORKSPACE/wrt/package/aliyundrive-webdav/openwrt"
  "$GITHUB_WORKSPACE/wrt/feeds/extra"
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
  echo "${plugin#luci-*}" | sed -E 's/^(app|theme)-//'
}

# 增强版插件查找（支持多级目录和别名）
find_plugin_dir() {
  local plugin=$1
  local search_name="${plugin#luci-}"
  
  for path in "${SEARCH_PATHS[@]}"; do
    # 查找可能的目录（包括子目录）
    found=$(find "$path" -type d -iname "*${search_name}*" -print -quit)
    [ -n "$found" ] && echo "$found" && return 0
  done
  return 1
}

# 智能po文件查找
find_po_file() {
  local dir=$1
  # 查找优先级：zh-cn > zh_Hans > 首个.po文件
  local po_file=$(find "$dir" -type f \( -path "*/po/zh-cn/*.po" -o -path "*/po/zh_Hans/*.po" \) -print -quit)
  [ -z "$po_file" ] && po_file=$(find "$dir" -type f -name "*.po" -print -quit)
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
      echo "[错误] 未找到.po文件: $plugin (搜索路径: $plugin_dir/po/)"
      continue
    fi

    # 转换语言包
    if po2lmo "$po_file" "$lmo_file"; then
      echo "[成功] 生成: $lmo_file (来源: $po_file)"
    else
      echo "[错误] 转换失败: $po_file → $lmo_file"
      rm -f "$lmo_file" 2>/dev/null
    fi
  done
}

# 精确验证（仅检查实际处理的插件）
validate_results() {
  echo "===== 验证结果 ====="
  local all_success=true

  for plugin in $WRT_LIST; do
    lmo_name=$(get_lmo_name "$plugin")
    lmo_file="$STAGING_I18N/${lmo_name}.zh-cn.lmo"
    
    # 仅验证理论上应该存在的语言包
    if [ -f "$lmo_file" ]; then
      echo "[通过] $plugin → $(basename "$lmo_file")"
    else
      # 检查是否真的需要该语言包
      if plugin_dir=$(find_plugin_dir "$plugin") && [ -n "$(find_po_file "$plugin_dir")" ]; then
        echo "[失败] 缺失语言包: $plugin (应存在: ${lmo_name}.zh-cn.lmo)"
        all_success=false
      else
        echo "[跳过] 无翻译文件: $plugin"
      fi
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
