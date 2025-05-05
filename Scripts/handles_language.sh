#!/bin/bash

# Handles_language.sh: 改进后的语言包处理脚本

# Paths
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
INSTALL_GLOBAL_PATH="/usr/lib/lua/luci/i18n/"  # 固件运行时的语言包路径
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

# 确认构建阶段的语言包路径
confirm_language_package_path() {
  echo "Confirming existing language package paths..." | tee -a "$LOG_FILE"
  EXISTING_LANG_FILES=$(find "$OUTPUT_PATH" -type f -name "*.zh-cn.lmo" -print || echo "")
  if [ -z "$EXISTING_LANG_FILES" ]; then
    echo "Warning: No existing language packages found in $OUTPUT_PATH. Defaulting to $INSTALL_GLOBAL_PATH in build directory." | tee -a "$LOG_FILE"
    BUILD_LANG_PATH="$OUTPUT_PATH$INSTALL_GLOBAL_PATH"
  else
    BUILD_LANG_PATH=$(dirname "$(echo "$EXISTING_LANG_FILES" | head -n 1)")
    echo "Detected build language package path: $BUILD_LANG_PATH" | tee -a "$LOG_FILE"
  fi
}

# 获取现有语言包列表
get_existing_plugins() {
  if [ -n "$EXISTING_LANG_FILES" ]; then
    EXISTING_PLUGINS=$(echo "$EXISTING_LANG_FILES" | xargs -n1 basename | sed 's/.zh-cn.lmo//' || echo "")
  else
    EXISTING_PLUGINS=""
  fi
}

# 筛选缺少语言包的插件
get_missing_language_packs() {
  NEED_LANG_PACKS=$(comm -23 <(echo "$PLUGIN_LIST" | sort) <(echo "$EXISTING_PLUGINS" | sort) || echo "")
}

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

      OUTPUT_FILE="$BUILD_LANG_PATH/$lmo_file"
      echo "Converting $po_file to $OUTPUT_FILE..." | tee -a "$LOG_FILE"
      if ! po2lmo "$po_file" "$OUTPUT_FILE"; then
        echo "Warning: Failed to convert $po_file to $lmo_file. Skipping..." | tee -a "$LOG_FILE"
        continue
      fi
      echo "Installed $lmo_file to $BUILD_LANG_PATH" | tee -a "$LOG_FILE"
    done
  done
}

# 验证语言包安装
validate_language_packages() {
  echo "Validating installed language packages..." | tee -a "$LOG_FILE"
  for plugin_name in $PLUGIN_LIST; do
    lmo_file="${plugin_name}.zh-cn.lmo"
    if ! find "$BUILD_LANG_PATH" -name "$lmo_file" &>/dev/null; then
      echo "Warning: Language package for $plugin_name is missing." | tee -a "$LOG_FILE"
    else
      echo "Language package for $plugin_name is successfully installed." | tee -a "$LOG_FILE"
    fi
  done
}

# 确认构建阶段语言包路径
confirm_language_package_path
# 获取已存在语言包的插件
get_existing_plugins
# 获取缺少语言包的插件
get_missing_language_packs
# 转换缺少的语言包
process_language_packages
# 验证语言包安装
validate_language_packages
