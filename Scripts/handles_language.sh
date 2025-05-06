#!/bin/bash

# 修正后的语言包处理脚本，解决路径和文件名问题

# Paths
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
# 动态获取目标架构和子目标（通过环境变量）
TARGET_ARCH=$(ls -d $GITHUB_WORKSPACE/wrt/staging_dir/target-* | xargs -n1 basename | sed 's/target-//')
SUBTARGET=$(ls -d $GITHUB_WORKSPACE/wrt/staging_dir/target-*/root-* | xargs -n1 basename | sed 's/root-//')
STAGING_PATH="$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH/root-$SUBTARGET/usr/lib/lua/luci/i18n/"
LOG_FILE="$OUTPUT_PATH/language_package_log.txt"

# 创建输出目录和日志文件
mkdir -p "$OUTPUT_PATH"
mkdir -p "$STAGING_PATH"
echo "Language Package Processing Log" > "$LOG_FILE"

# 检查 po2lmo 工具是否可用
if ! command -v po2lmo &> /dev/null; then
  echo "Warning: po2lmo tool is not installed or not available in PATH." | tee -a "$LOG_FILE"
  exit 0
fi

# 从环境变量中获取插件列表
PLUGIN_LIST=$(echo "$WRT_LIST" | tr ' ' '\n')

# 获取构建阶段的 `.lmo` 文件路径
confirm_language_package_path() {
  echo "Confirming existing language package paths..." | tee -a "$LOG_FILE"
  if [ -d "$STAGING_PATH" ]; then
    BUILD_LANG_PATH="$STAGING_PATH"
    echo "Detected build language package path: $BUILD_LANG_PATH" | tee -a "$LOG_FILE"
  else
    echo "Warning: No staging directory found. Creating default path at $STAGING_PATH" | tee -a "$LOG_FILE"
    mkdir -p "$STAGING_PATH"
    BUILD_LANG_PATH="$STAGING_PATH"
  fi
}

# 转换语言包
process_language_packages() {
  echo "Processing .po files to .lmo for zh-cn..." | tee -a "$LOG_FILE"

  for plugin_name in $PLUGIN_LIST; do
    # 去除插件名前缀（如 luci-app-）
    clean_name=$(echo "$plugin_name" | sed 's/^luci-\(app\|theme\)-//')
    plugin_path=$(find "$PKG_PATH" -type d -name "$plugin_name" -print -quit || echo "")
    if [ -z "$plugin_path" ]; then
      echo "Warning: Plugin $plugin_name not found in package directory. Skipping..." | tee -a "$LOG_FILE"
      continue
    fi

    # 查找插件中的 .po 文件
    find "$plugin_path" -type f -name "*.po" | while read -r po_file; do
      po_basename=$(basename "$po_file" .po || echo "")
      lmo_file="${clean_name}.zh-cn.lmo"  # 使用清理后的名称

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
    clean_name=$(echo "$plugin_name" | sed 's/^luci-\(app\|theme\)-//')
    lmo_file="${clean_name}.zh-cn.lmo"  # 使用清理后的名称
    if ! find "$BUILD_LANG_PATH" -name "$lmo_file" &>/dev/null; then
      echo "Warning: Language package for $plugin_name is missing." | tee -a "$LOG_FILE"
    else
      echo "Language package for $plugin_name is successfully installed." | tee -a "$LOG_FILE"
    fi
  done
}

# 执行主流程
confirm_language_package_path
process_language_packages
validate_language_packages
