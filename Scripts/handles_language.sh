#!/bin/bash
# 终极版语言包处理脚本 - 集成动态路径探测、智能过滤、并发处理和详细日志

# 动态获取目标架构和子目标（兼容多平台）
TARGET_ARCH=$(find "$GITHUB_WORKSPACE/wrt/staging_dir" -maxdepth 1 -type d -name "target-*" | head -n1 | xargs basename | sed 's/target-//')
SUBTARGET=$(find "$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH" -maxdepth 1 -type d -name "root-*" | head -n1 | xargs basename | sed 's/root-//')

# 路径配置（覆盖所有可能的插件位置）
SEARCH_PATHS=(
  "$GITHUB_WORKSPACE/wrt/package"
  "$GITHUB_WORKSPACE/wrt/feeds/luci"
  "$GITHUB_WORKSPACE/wrt/feeds/packages"
  "$GITHUB_WORKSPACE/wrt/feeds/extra"
)
STAGING_PATH="$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH/root-$SUBTARGET/usr/lib/lua/luci/i18n"
LOG_DIR="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files"
MAIN_LOG="$LOG_DIR/language_package_main.log"
PLUGIN_LOG_DIR="$LOG_DIR/plugin_logs"

# 初始化环境
mkdir -p "$STAGING_PATH" "$PLUGIN_LOG_DIR"
echo "=== Language Package Processing Started ===" > "$MAIN_LOG"
echo "Target Arch: $TARGET_ARCH" >> "$MAIN_LOG"
echo "Subtarget: $SUBTARGET" >> "$MAIN_LOG"

# 工具链检查
if ! command -v po2lmo &> /dev/null; then
  echo "ERROR: po2lmo not found. Run 'sudo apt install po4a'" | tee -a "$MAIN_LOG"
  exit 1
fi

# 核心函数：获取有效插件列表
get_valid_plugins() {
  local valid_plugins=""
  for plugin in $WRT_LIST; do
    # 智能去除前缀（兼容luci-app-和luci-theme-）
    clean_name=$(echo "$plugin" | sed -E 's/^luci-(app|theme)-//')
    
    # 多路径搜索插件目录
    plugin_path=""
    for base_path in "${SEARCH_PATHS[@]}"; do
      plugin_path=$(find "$base_path" -type d -name "*${clean_name}*" -print -quit 2>/dev/null)
      [ -n "$plugin_path" ] && break
    done

    if [ -n "$plugin_path" ]; then
      # 检查是否已存在语言包
      if [ ! -f "$STAGING_PATH/${clean_name}.zh-cn.lmo" ]; then
        valid_plugins="$valid_plugins $plugin_path"
        echo "QUEUED: $plugin (path: $plugin_path)" >> "$MAIN_LOG"
      else
        echo "SKIPPED: $plugin (already exists)" >> "$MAIN_LOG"
      fi
    else
      echo "WARNING: Plugin $plugin not found in any search path" >> "$MAIN_LOG"
    fi
  done
  echo "$valid_plugins"
}

# 并发转换语言包（最大并行数=CPU核心数）
convert_po_files() {
  local plugin_path=$1
  local plugin_name=$(basename "$plugin_path")
  local clean_name=$(echo "$plugin_name" | sed -E 's/^luci-(app|theme)-//')
  local plugin_log="$PLUGIN_LOG_DIR/${clean_name}.log"

  echo "PROCESSING: $plugin_name" > "$plugin_log"
  
  # 查找所有中文po文件（兼容zh-cn/zh_Hans等格式）
  find "$plugin_path" -type f \( -path "*/po/zh-cn/*.po" -o -path "*/po/zh_Hans/*.po" \) -print0 | while IFS= read -r -d '' po_file; do
    po_basename=$(basename "$po_file" .po)
    lmo_file="$STAGING_PATH/${po_basename}.zh-cn.lmo"
    
    echo "Converting: $po_file → $lmo_file" >> "$plugin_log"
    if po2lmo "$po_file" "$lmo_file"; then
      echo "SUCCESS: Generated $lmo_file" >> "$plugin_log"
    else
      echo "ERROR: Failed to convert $po_file" >> "$plugin_log"
    fi
  done
}

# 主流程
VALID_PLUGINS=$(get_valid_plugins)
echo "=== Valid Plugins List ===" >> "$MAIN_LOG"
echo "$VALID_PLUGINS" | tr ' ' '\n' >> "$MAIN_LOG"

# 并发处理（通过xargs控制并行度）
echo "$VALID_PLUGINS" | xargs -n1 -P$(nproc) -I{} bash -c 'convert_po_files "{}"'

# 最终验证
echo "=== Validation Results ===" >> "$MAIN_LOG"
for plugin in $WRT_LIST; do
  clean_name=$(echo "$plugin" | sed -E 's/^luci-(app|theme)-//')
  if [ -f "$STAGING_PATH/${clean_name}.zh-cn.lmo" ]; then
    echo "PASS: $plugin has valid language pack" >> "$MAIN_LOG"
  else
    echo "FAIL: $plugin missing language pack" >> "$MAIN_LOG"
  fi
done

echo "=== Processing Complete ===" >> "$MAIN_LOG"
