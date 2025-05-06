#!/bin/bash

# Handles_language.sh: 进一步优化的语言包处理脚本

# 动态获取目标架构和子目标架构
TARGET_ARCH=$(find "$GITHUB_WORKSPACE/wrt/staging_dir" -maxdepth 1 -type d -name "target-*" | head -n 1 | xargs -n1 basename | sed 's/target-//')
SUBTARGET=$(find "$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH" -maxdepth 1 -type d -name "root-*" | head -n 1 | xargs -n1 basename | sed 's/root-//')

# Paths
PKG_PATHS=(
  "$GITHUB_WORKSPACE/wrt/package/"
  "$GITHUB_WORKSPACE/wrt/feeds/luci/"
  "$GITHUB_WORKSPACE/wrt/feeds/packages/"
)
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
STAGING_PATH="$GITHUB_WORKSPACE/wrt/staging_dir/target-${TARGET_ARCH}/root-${SUBTARGET}/usr/lib/lua/luci/i18n/"
MAIN_LOG_FILE="$OUTPUT_PATH/language_package_log.txt"

# 创建输出目录和日志文件
mkdir -p "$OUTPUT_PATH"
mkdir -p "$STAGING_PATH"
echo "Language Package Processing Log" > "$MAIN_LOG_FILE"

# 检查 po2lmo 工具是否可用
if ! command -v po2lmo &> /dev/null; then
  echo "Error: po2lmo tool is not installed or not available in PATH." | tee -a "$MAIN_LOG_FILE"
  exit 1
fi

# 从环境变量中获取插件列表
PLUGIN_LIST=$(echo "$WRT_LIST" | tr ' ' '\n')

# 确认语言包路径
confirm_language_package_path() {
  echo "Confirming existing language package paths..." | tee -a "$MAIN_LOG_FILE"
  if [ -d "$STAGING_PATH" ]; then
    BUILD_LANG_PATH="$STAGING_PATH"
    echo "Detected build language package path: $BUILD_LANG_PATH" | tee -a "$MAIN_LOG_FILE"
  else
    echo "Warning: Staging directory not found. Creating it at $STAGING_PATH..." | tee -a "$MAIN_LOG_FILE"
    mkdir -p "$STAGING_PATH"
    BUILD_LANG_PATH="$STAGING_PATH"
  fi
}

# 获取已有语言包列表
get_existing_language_packages() {
  EXISTING_LANG_FILES=$(find "$BUILD_LANG_PATH" -type f -name "*.zh-cn.lmo" -print || echo "")
  EXISTING_PLUGINS=""
  if [ -n "$EXISTING_LANG_FILES" ]; then
    EXISTING_PLUGINS=$(echo "$EXISTING_LANG_FILES" | xargs -n1 basename | sed 's/.zh-cn.lmo//' || echo "")
  fi
}

# 筛选缺少语言包的插件
get_missing_language_packs() {
  NEED_LANG_PACKS=$(comm -23 <(echo "$PLUGIN_LIST" | sort) <(echo "$EXISTING_PLUGINS" | sort) || echo "")
}

# 转换语言包
process_language_packages() {
  echo "Processing .po files to .lmo for zh-cn..." | tee -a "$MAIN_LOG_FILE"

  for plugin_name in $NEED_LANG_PACKS; do
    plugin_log_file="$OUTPUT_PATH/${plugin_name}_log.txt"
    echo "Processing plugin: $plugin_name" > "$plugin_log_file"

    # 去除插件名前缀
    clean_name=$(echo "$plugin_name" | sed 's/^luci-\(app\|theme\)-//')
    plugin_path=""
    for base_path in "${PKG_PATHS[@]}"; do
      plugin_path=$(find "$base_path" -type d -name "$plugin_name" -print -quit || echo "")
      if [ -n "$plugin_path" ]; then
        break
      fi
    done

    if [ -z "$plugin_path" ]; then
      echo "Warning: Plugin $plugin_name not found in package directories. Skipping..." | tee -a "$plugin_log_file"
      continue
    fi

    # 查找并并发转换 .po 文件
    find "$plugin_path" -type f -name "*.po" | while read -r po_file; do
      po_basename=$(basename "$po_file" .po || echo "")
      lmo_file="${clean_name}.zh-cn.lmo"

      OUTPUT_FILE="$BUILD_LANG_PATH/$lmo_file"
      echo "Converting $po_file to $OUTPUT_FILE..." | tee -a "$plugin_log_file"
      if ! po2lmo "$po_file" "$OUTPUT_FILE"; then
        echo "Error: Failed to convert $po_file to $lmo_file. Skipping..." | tee -a "$plugin_log_file"
        continue
      fi
      echo "Installed $lmo_file to $BUILD_LANG_PATH" | tee -a "$plugin_log_file"
    done
  done
}

# 验证语言包安装
validate_language_packages() {
  echo "Validating installed language packages..." | tee -a "$MAIN_LOG_FILE"
  for plugin_name in $PLUGIN_LIST; do
    clean_name=$(echo "$plugin_name" | sed 's/^luci-\(app\|theme\)-//')
    lmo_file="${clean_name}.zh-cn.lmo"

    if ! find "$BUILD_LANG_PATH" -name "$lmo_file" &>/dev/null; then
      echo "Warning: Language package for $plugin_name is missing." | tee -a "$MAIN_LOG_FILE"
    else
      echo "Language package for $plugin_name is successfully installed." | tee -a "$MAIN_LOG_FILE"
    fi
  done
}

# 执行主流程
confirm_language_package_path
get_existing_language_packages
get_missing_language_packs
process_language_packages
validate_language_packages
