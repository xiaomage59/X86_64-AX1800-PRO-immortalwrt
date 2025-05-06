#!/bin/bash

# Paths
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
TARGET_ARCH=$(ls -d $GITHUB_WORKSPACE/wrt/staging_dir/target-* | xargs -n1 basename | sed 's/target-//')
SUBTARGET=$(ls -d $GITHUB_WORKSPACE/wrt/staging_dir/target-*/root-* | xargs -n1 basename | sed 's/root-//')
STAGING_PATH="$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH/root-$SUBTARGET/usr/lib/lua/luci/i18n/"
LOG_FILE="$OUTPUT_PATH/language_package_log.txt"

# 创建目录和日志
mkdir -p "$OUTPUT_PATH" "$STAGING_PATH"
echo "Language Package Processing Log" > "$LOG_FILE"

# 检查工具链
if ! command -v po2lmo &> /dev/null; then
  echo "Error: po2lmo not found. Install with 'sudo apt install po4a'." | tee -a "$LOG_FILE"
  exit 1
fi

# 转换语言包
process_language_packages() {
  echo "Processing .po files..." | tee -a "$LOG_FILE"
  
  # 遍历插件列表
  for plugin in $WRT_LIST; do
    # 提取插件核心名称（例如 luci-app-alist → alist）
    clean_name=$(echo "$plugin" | sed -E 's/^luci-(app|theme)-//')
    
    # 查找插件的 .po 文件（匹配 zh-cn/zh_Hans 目录）
    find "$PKG_PATH/$plugin" -type f -path "*/po/zh[-_]*/*.po" | while read -r po_file; do
      # 提取 .po 文件基名（例如 alist.po → alist）
      po_basename=$(basename "$po_file" .po)
      
      # 生成目标 .lmo 文件名（例如 alist.zh-cn.lmo）
      lmo_file="${po_basename}.zh-cn.lmo"
      output_path="$STAGING_PATH/$lmo_file"
      
      echo "Converting $po_file to $output_path" | tee -a "$LOG_FILE"
      if ! po2lmo "$po_file" "$output_path"; then
        echo "Error: Failed to convert $po_file" | tee -a "$LOG_FILE"
      fi
    done
  done
}

# 验证语言包
validate_language_packages() {
  echo "Validating language packages..." | tee -a "$LOG_FILE"
  for plugin in $WRT_LIST; do
    clean_name=$(echo "$plugin" | sed -E 's/^luci-(app|theme)-//')
    # 预期生成的 .lmo 文件名（例如 alist.zh-cn.lmo）
    expected_lmo="${clean_name}.zh-cn.lmo"
    if [ ! -f "$STAGING_PATH/$expected_lmo" ]; then
      echo "Warning: Missing $expected_lmo for $plugin" | tee -a "$LOG_FILE"
    fi
  done
}

# 执行主流程
process_language_packages
validate_language_packages
