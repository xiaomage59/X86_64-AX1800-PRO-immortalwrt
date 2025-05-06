#!/bin/bash

# 修正后的语言包处理脚本，解决路径匹配和文件名问题

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

# 获取有效插件列表（过滤不存在的插件）
VALID_PLUGINS=""
for plugin in $WRT_LIST; do
  if find "$PKG_PATH" -type d -name "$plugin" | grep -q .; then
    VALID_PLUGINS="$VALID_PLUGINS $plugin"
  else
    echo "Warning: Skip non-existent plugin $plugin" | tee -a "$LOG_FILE"
  fi
done

# 转换语言包
process_language_packages() {
  echo "Processing .po files for valid plugins: $VALID_PLUGINS" | tee -a "$LOG_FILE"
  
  for plugin in $VALID_PLUGINS; do
    # 生成标准化的 lmo 文件名
    clean_name=$(echo "$plugin" | sed -E 's/^luci-(app|theme)-//')
    lmo_prefix="luci-i18n-${clean_name}-zh-cn"

    # 查找所有 .po 文件
    find "$PKG_PATH/$plugin" -type f -name "*.po" | while read -r po_file; do
      # 提取语言区域（如 zh-cn/zh_Hans）
      lang_dir=$(dirname "$po_file" | xargs basename)
      case "$lang_dir" in
        zh-cn|zh_Hans|zh_CN)
          lmo_file="${lmo_prefix}.lmo"
          output_path="$STAGING_PATH/$lmo_file"
          echo "Converting $po_file to $output_path" | tee -a "$LOG_FILE"
          po2lmo "$po_file" "$output_path" || echo "Error: Convert $po_file failed" | tee -a "$LOG_FILE"
          ;;
        *)
          echo "Skip non-ZH po file: $po_file" | tee -a "$LOG_FILE"
          ;;
      esac
    done
  done
}

# 验证语言包
validate_language_packages() {
  echo "Validating language packages..." | tee -a "$LOG_FILE"
  for plugin in $VALID_PLUGINS; do
    clean_name=$(echo "$plugin" | sed -E 's/^luci-(app|theme)-//')
    lmo_file="luci-i18n-${clean_name}-zh-cn.lmo"
    if [ ! -f "$STAGING_PATH/$lmo_file" ]; then
      echo "Error: Missing $lmo_file for $plugin" | tee -a "$LOG_FILE"
    fi
  done
}

# 执行主流程
process_language_packages
validate_language_packages
