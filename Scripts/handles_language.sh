#!/bin/bash

# Handles_language.sh: 改进后的语言包处理脚本，确保完整性和对 Compile Firmware 阶段的适配

# Paths
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
INSTALL_GLOBAL_PATH="/usr/lib/lua/luci/i18n/"  # 语言包的全局安装路径（运行时路径）
LOG_FILE="$OUTPUT_PATH/language_package_log.txt"

# 创建输出目录和日志文件
mkdir -p "$OUTPUT_PATH"
echo "Language Package Processing Log" > "$LOG_FILE"

# 检查 po2lmo 工具是否可用
if ! command -v po2lmo &> /dev/null; then
  echo "Warning: po2lmo tool is not installed or not available in PATH." | tee -a "$LOG_FILE"
  exit 0
fi

# 从环境变量中获取插件列表
PLUGIN_LIST=$(echo "$WRT_LIST" | tr ' ' '\n')

# 获取现有语言包列表
EXISTING_LANG_FILES=$(find "$OUTPUT_PATH" -type f -name "*.zh-cn.lmo" -print || echo "")
EXISTING_PLUGINS=$(echo "$EXISTING_LANG_FILES" | xargs -n1 basename | sed 's/.zh-cn.lmo//' || echo "")

# 筛选缺少语言包的插件
NEED_LANG_PACKS=$(comm -23 <(echo "$PLUGIN_LIST" | sort) <(echo "$EXISTING_PLUGINS" | sort) || echo "")

# 转换语言包
process_language_packages() {
  echo "Processing .po files to .lmo for zh-cn..." | tee -a "$LOG_FILE"

  for plugin_name in $NEED_LANG_PACKS; do
    plugin_path=$(find "$PKG_PATH" -type d -name "$plugin_name" -print -quit || echo "")
    if [ -z "$plugin_path" ]; then
      echo "Warning: Plugin $plugin_name not found in package directory. Skipping..." | tee -a "$LOG_FILE"
      continue
    fi

    # 查找插件中的 .po 文件
    find "$plugin_path" -type f -name "*.po" | while read -r po_file; do
      po_basename=$(basename "$po_file" .po || echo "")
      lmo_file="${po_basename}.zh-cn.lmo"

      if [ -z "$po_basename" ]; then
        echo "Warning: Failed to process $po_file. Skipping..." | tee -a "$LOG_FILE"
        continue
      fi

      echo "Converting $po_file to $OUTPUT_PATH/$lmo_file..." | tee -a "$LOG_FILE"
      if ! po2lmo "$po_file" "$OUTPUT_PATH/$lmo_file"; then
        echo "Warning: Failed to convert $po_file to $lmo_file. Skipping..." | tee -a "$LOG_FILE"
        continue
      fi

      # 安装语言包到全局路径
      mkdir -p "$OUTPUT_PATH/$INSTALL_GLOBAL_PATH"
      cp "$OUTPUT_PATH/$lmo_file" "$OUTPUT_PATH/$INSTALL_GLOBAL_PATH"
      echo "Installed $lmo_file to $INSTALL_GLOBAL_PATH" | tee -a "$LOG_FILE"
    done
  done
}

# 验证语言包安装
validate_language_packages() {
  echo "Validating installed language packages..." | tee -a "$LOG_FILE"
  for plugin_name in $PLUGIN_LIST; do
    lmo_file="${plugin_name}.zh-cn.lmo"
    if ! find "$OUTPUT_PATH/$INSTALL_GLOBAL_PATH" -name "$lmo_file" &>/dev/null; then
      echo "Warning: Language package for $plugin_name is missing." | tee -a "$LOG_FILE"
    else
      echo "Language package for $plugin_name is successfully installed." | tee -a "$LOG_FILE"
    fi
  done
}

# 执行逻辑
process_language_packages
validate_language_packages
