#!/bin/bash
# 语言包处理脚本 - 优化版

# 动态获取架构
TARGET_ARCH=$(find "$GITHUB_WORKSPACE/wrt/staging_dir" -maxdepth 1 -type d -name "target-*" | head -n1 | xargs basename | sed 's/target-//')
SUBTARGET=$(find "$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH" -maxdepth 1 -type d -name "root-*" | head -n1 | xargs basename | sed 's/root-//')

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

# 获取已存在的语言包列表
get_existing_lmo_files() {
  find "$STAGING_I18N" -name "*.zh-cn.lmo" -exec basename {} \; | \
    sed 's/\.zh-cn\.lmo$//' | sort | uniq
}

# 扩展搜索路径（包含所有可能位置）
SEARCH_PATHS=(
  "$GITHUB_WORKSPACE/wrt/package"
  "$GITHUB_WORKSPACE/wrt/feeds/luci"
  "$GITHUB_WORKSPACE/wrt/feeds/packages"
  "$GITHUB_WORKSPACE/wrt/feeds/luci/applications"
  "$GITHUB_WORKSPACE/wrt/feeds/luci/themes"
  "$GITHUB_WORKSPACE/wrt/feeds/packages/net"
  "$GITHUB_WORKSPACE/wrt/feeds/packages/utils"
)

# 查找插件目录
find_plugin_dir() {
  local plugin=$1
  local search_name="${plugin#luci-}"
  
  for path in "${SEARCH_PATHS[@]}"; do
    # 使用精确匹配优先，然后模糊匹配
    found=$(find "$path" -type d -name "$plugin" -print -quit)
    [ -z "$found" ] && found=$(find "$path" -type d -iname "*${plugin}*" -print -quit)
    [ -n "$found" ] && echo "$found" && return 0
  done
  return 1
}

# 查找PO文件
find_po_file() {
  local dir=$1
  # 查找优先级：zh-cn > zh_Hans > 任意位置
  local po_file=$(find "$dir" -type f \( -path "*/po/zh-cn/*.po" -o -path "*/po/zh_Hans/*.po" \) -print -quit)
  [ -z "$po_file" ] && po_file=$(find "$dir" -type f \( -path "*/i18n/*.po" -o -path "*/po/*.po" \) -print -quit)
  echo "$po_file"
}

# 主处理流程
process_missing_languages() {
  echo "===== 开始处理缺失语言包 ====="
  
  # 获取现有语言包列表
  existing_lmos=$(get_existing_lmo_files)
  
  # 筛选缺失语言包的插件
  declare -a missing_plugins=()
  for plugin in $WRT_LIST; do
    # 跳过主题包
    [[ $plugin == luci-theme-* ]] && continue
    
    lmo_name=$(get_lmo_name "$plugin")
    if ! grep -q "^${lmo_name}$" <<< "$existing_lmos"; then
      missing_plugins+=("$plugin")
    fi
  done

  echo "需要处理的插件数量: ${#missing_plugins[@]}"
  echo "缺失语言包的插件列表: ${missing_plugins[*]}"
  
  # 处理缺失语言包的插件
  local processed=0
  for plugin in "${missing_plugins[@]}"; do
    lmo_name=$(get_lmo_name "$plugin")
    lmo_file="$STAGING_I18N/${lmo_name}.zh-cn.lmo"
    
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
        ((processed++))
      else
        echo "[错误] 转换失败: $po_file → $lmo_file"
        rm -f "$lmo_file" 2>/dev/null
      fi
    else
      echo "[错误] .po文件不存在: $plugin_dir"
    fi
  done

  echo "成功处理 $processed 个插件的语言包"
}

# 验证结果
validate_results() {
  echo "===== 验证结果 ====="
  local all_success=true
  local missing_count=0
  
  # 获取现有语言包列表
  existing_lmos=$(get_existing_lmo_files)
  
  for plugin in $WRT_LIST; do
    # 跳过主题包
    [[ $plugin == luci-theme-* ]] && continue
    
    lmo_name=$(get_lmo_name "$plugin")
    if grep -q "^${lmo_name}$" <<< "$existing_lmos"; then
      echo "[通过] $plugin → ${lmo_name}.zh-cn.lmo"
    else
      # 检查是否真的需要该语言包
      if plugin_dir=$(find_plugin_dir "$plugin") && [ -n "$(find_po_file "$plugin_dir")" ]; then
        echo "[失败] 缺失语言包: $plugin (应存在: ${lmo_name}.zh-cn.lmo)"
        all_success=false
        ((missing_count++))
      else
        echo "[跳过] 无翻译文件: $plugin"
      fi
    fi
  done

  if [ $missing_count -gt 0 ]; then
    echo "===== 存在 $missing_count 个缺失的语言包 ====="
    return 1
  else
    echo "===== 所有语言包验证通过 ====="
    return 0
  fi
}

# 执行流程
process_missing_languages
validate_results

# 生成清单文件（用于调试）
find "$STAGING_I18N" -name "*.zh-cn.lmo" | sort > "$LOG_DIR/generated_lmo_files.txt"
echo "===== 已生成的语言包清单 ====="
cat "$LOG_DIR/generated_lmo_files.txt"

# 生成处理摘要
{
  echo "===== 语言包处理摘要 ====="
  echo "目标架构: $TARGET_ARCH"
  echo "处理的插件总数: $(wc -w <<< "$WRT_LIST")"
  echo "缺失语言包的插件数量: $(get_existing_lmo_files | wc -l)"
  echo "最终语言包数量: $(find "$STAGING_I18N" -name "*.zh-cn.lmo" | wc -l)"
  echo "处理时间: $(date)"
} > "$LOG_DIR/language_package_summary.log"

cat "$LOG_DIR/language_package_summary.log"
