#!/bin/bash

# 路径定义
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
STAGING_PATH="$GITHUB_WORKSPACE/wrt/staging_dir/target-$(ls -d $GITHUB_WORKSPACE/wrt/staging_dir/target-* | xargs -n1 basename | sed 's/target-//')/root-$(ls -d $GITHUB_WORKSPACE/wrt/staging_dir/target-*/root-* | xargs -n1 basename | sed 's/root-//')/usr/lib/lua/luci/i18n/"
LOG_FILE="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/language_package_log.txt"

# 初始化日志
mkdir -p "$(dirname "$LOG_FILE")"
echo "Language Package Processing Log" > "$LOG_FILE"

# 检查工具链
if ! command -v po2lmo &> /dev/null; then
  echo "Error: po2lmo not found. Install with 'sudo apt install po4a'." | tee -a "$LOG_FILE"
  exit 1
fi

# 获取已存在的语言包列表
EXISTING_LMO=$(find "$STAGING_PATH" -name "*.zh-cn.lmo" -exec basename {} \; | sed 's/.zh-cn.lmo//')

# 处理插件列表：过滤无效插件并生成待处理列表
VALID_PLUGINS=""
for plugin in $WRT_LIST; do
  # 尝试匹配插件目录（兼容不同命名风格）
  plugin_dir=$(find "$PKG_PATH" -type d -name "*$(echo "$plugin" | sed 's/^luci-//')*" -print -quit)
  if [ -n "$plugin_dir" ]; then
    clean_name=$(basename "$plugin_dir" | sed 's/^luci-//')
    # 检查语言包是否已存在
    if ! echo "$EXISTING_LMO" | grep -q "^$clean_name$"; then
      VALID_PLUGINS="$VALID_PLUGINS $plugin_dir"
      echo "Queue plugin for processing: $plugin_dir" | tee -a "$LOG_FILE"
    else
      echo "Skip existing language package: $clean_name" | tee -a "$LOG_FILE"
    fi
  else
    echo "Warning: Plugin directory not found for $plugin" | tee -a "$LOG_FILE"
  fi
done

# 转换语言包
process_language_packages() {
  for plugin_dir in $VALID_PLUGINS; do
    find "$plugin_dir" -type f -path "*/po/zh[-_]*/*.po" | while read -r po_file; do
      po_basename=$(basename "$po_file" .po)
      lmo_file="$STAGING_PATH/${po_basename}.zh-cn.lmo"
      echo "Converting $po_file to $lmo_file" | tee -a "$LOG_FILE"
      po2lmo "$po_file" "$lmo_file" || echo "Error: Failed to convert $po_file" | tee -a "$LOG_FILE"
    done
  done
}

# 验证语言包
validate_language_packages() {
  echo "Validating language packages..." | tee -a "$LOG_FILE"
  for plugin in $WRT_LIST; do
    clean_name=$(echo "$plugin" | sed 's/^luci-//')
    if [ ! -f "$STAGING_PATH/${clean_name}.zh-cn.lmo" ]; then
      echo "Error: Missing language package for $plugin (expected: ${clean_name}.zh-cn.lmo)" | tee -a "$LOG_FILE"
    fi
  done
}

# 执行流程
process_language_packages
validate_language_packages
