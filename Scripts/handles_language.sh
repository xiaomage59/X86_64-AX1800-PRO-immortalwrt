#!/bin/bash

# 动态获取目标架构和子目标
TARGET_ARCH=$(find "$GITHUB_WORKSPACE/wrt/staging_dir" -maxdepth 1 -type d -name "target-*" | head -n1 | xargs basename | sed 's/target-//')
SUBTARGET=$(find "$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH" -maxdepth 1 -type d -name "root-*" | head -n1 | xargs basename | sed 's/root-//')

# 路径配置
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
echo "=== Language Package Processing Started === $(date)" > "$MAIN_LOG"
echo "Target Arch: $TARGET_ARCH" >> "$MAIN_LOG"
echo "Subtarget: $SUBTARGET" >> "$MAIN_LOG"

# 检查工具
if ! command -v po2lmo &> /dev/null; then
  echo "ERROR: po2lmo not found. Install it using 'sudo apt install po4a'" | tee -a "$MAIN_LOG"
  exit 1
fi

# 筛选目标语言的 `.po` 文件
find_po_files() {
  local plugin_path=$1
  find "$plugin_path" -type f \( -path "*/po/zh-cn/*.po" -o -path "*/po/zh_Hans/*.po" \) -print
}

# 核心函数：获取有效插件列表
get_missing_language_plugins() {
  local valid_plugins=""
  for plugin in $WRT_LIST; do
    # 去除插件名前缀（如 luci-app-）
    clean_name=$(echo "$plugin" | sed -E 's/^luci-(app|theme)-//')
    
    # 多路径搜索插件目录
    plugin_path=""
    for base_path in "${SEARCH_PATHS[@]}"; do
      plugin_path=$(find "$base_path" -type d -name "*${clean_name}*" -print -quit 2>/dev/null)
      [ -n "$plugin_path" ] && break
    done

    if [ -n "$plugin_path" ]; then
      # 检查是否已有语言包
      if [ -n "$plugin_path" ]; then
      if [ ! -f "$STAGING_PATH/${clean_name}.zh-cn.lmo" ]; then
        valid_plugins="$valid_plugins"$'\n'"$plugin_path"
        echo "$(date) - QUEUED: $plugin (path: $plugin_path)" >> "$MAIN_LOG"
      else
        echo "$(date) - SKIPPED: $plugin (language package already exists)" >> "$MAIN_LOG"
      fi
    else
      echo "$(date) - WARNING: Plugin $plugin not found in any search path" >> "$MAIN_LOG"
    fi
  done
  echo "$valid_plugins"
}

# 转换语言包
convert_po_files() {
  local plugin_path=$1
  local plugin_name=$(basename "$plugin_path")
  local clean_name=$(echo "$plugin_name" | sed -E 's/^luci-(app|theme)-//')
  local plugin_log="$PLUGIN_LOG_DIR/${clean_name}.log"

  echo "$(date) - PROCESSING: $plugin_name" > "$plugin_log"

  # 检查路径是否存在
  if [ ! -d "$plugin_path" ]; then
    echo "$(date) - ERROR: Plugin path $plugin_path does not exist" >> "$plugin_log"
    return
  fi

  # 查找所有目标语言的 `.po` 文件
  find_po_files "$plugin_path" | while read -r po_file; do
    po_basename=$(basename "$po_file" .po)
    lmo_file="$STAGING_PATH/${po_basename}.zh-cn.lmo"

    echo "$(date) - Converting: $po_file → $lmo_file" >> "$plugin_log"
    if po2lmo "$po_file" "$lmo_file"; then
      echo "$(date) - SUCCESS: Generated $lmo_file" >> "$plugin_log"
    else
      echo "$(date) - ERROR: Failed to convert $po_file" >> "$plugin_log"
    fi
  done
}

# 导出函数以便子 shell 使用
export -f find_po_files
export -f convert_po_files
export STAGING_PATH
export MAIN_LOG
export PLUGIN_LOG_DIR

# 主流程
VALID_PLUGINS=$(get_missing_language_plugins)
if [ -z "$VALID_PLUGINS" ]; then
  echo "No plugins require language package processing. Exiting." >> "$MAIN_LOG"
  exit 0
fi

echo "=== Plugins Missing Language Packs === $(date)" >> "$MAIN_LOG"
echo "$VALID_PLUGINS" | tr ' ' '\n' >> "$MAIN_LOG"

# 并发处理（移除冲突参数 - 仅使用 -I）
echo "$VALID_PLUGINS" | xargs -d '\n' -P$(nproc) -I{} bash -c 'convert_po_files "{}"'

# 最终验证
echo "=== Validation Results === $(date)" >> "$MAIN_LOG"
for plugin in $WRT_LIST; do
  clean_name=$(echo "$plugin" | sed -E 's/^luci-(app|theme)-//')
  if [ -f "$STAGING_PATH/${clean_name}.zh-cn.lmo" ]; then
    echo "$(date) - PASS: $plugin has valid language pack" >> "$MAIN_LOG"
  else
    echo "$(date) - FAIL: $plugin missing language pack" >> "$MAIN_LOG"
  fi
done

echo "=== Processing Complete === $(date)" >> "$MAIN_LOG"
