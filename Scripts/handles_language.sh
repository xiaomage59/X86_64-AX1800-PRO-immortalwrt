#!/bin/bash

# Paths
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
INSTALL_DIR="/usr/lib/lua/luci/i18n/"
ROM_DIR="/rom/usr/lib/lua/luci/i18n/"

# 创建输出目录
mkdir -p "$OUTPUT_PATH"

# 检查 po2lmo 工具是否可用
if ! command -v po2lmo &> /dev/null; then
  echo "Error: po2lmo tool is not installed or not available in PATH."
  exit 1
fi

# 从环境变量中获取插件列表
PLUGIN_LIST=$(echo "$WRT_LIST" | tr ' ' '\n')

# 获取现有语言包列表
EXISTING_LANG_FILES=$(ls $INSTALL_DIR/*.zh-cn.lmo 2>/dev/null; ls $ROM_DIR/*.zh-cn.lmo 2>/dev/null)
EXISTING_PLUGINS=$(echo "$EXISTING_LANG_FILES" | xargs -n1 basename | sed 's/.zh-cn.lmo//')

# 筛选缺少语言包的插件
NEED_LANG_PACKS=$(comm -23 <(echo "$PLUGIN_LIST" | sort) <(echo "$EXISTING_PLUGINS" | sort))

# 转换语言包
process_language_packages() {
  echo "Processing .po files to .lmo for zh-cn..."

  # 遍历缺少语言包的插件
  for plugin_name in $NEED_LANG_PACKS; do
    plugin_path=$(find "$PKG_PATH" -type d -name "$plugin_name" -print -quit)
    if [ -z "$plugin_path" ]; then
      echo "Plugin $plugin_name not found in package directory. Skipping..."
      continue
    fi

    # 查找插件中的 .po 文件
    find "$plugin_path" -type f -name "*.po" | while read -r po_file; do
      po_basename=$(basename "$po_file" .po)
      lmo_file="${po_basename}.zh-cn.lmo"

      echo "Converting $po_file to $OUTPUT_PATH/$lmo_file..."
      po2lmo "$po_file" "$OUTPUT_PATH/$lmo_file"
    done
  done
}

# 安装语言包
install_lmo_files() {
  echo "Installing .lmo files to target directories..."
  find "$OUTPUT_PATH" -type f -name "*.lmo" | while read -r lmo_file; do
    echo "Installing $lmo_file to $INSTALL_DIR..."
    cp "$lmo_file" "$INSTALL_DIR"
  done
}

# 验证语言包安装
validate_language_packages() {
  echo "Validating installed language packages..."
  for plugin_name in $PLUGIN_LIST; do
    lmo_file="${plugin_name}.zh-cn.lmo"
    if [ ! -f "$INSTALL_DIR/$lmo_file" ] && [ ! -f "$ROM_DIR/$lmo_file" ]; then
      echo "Warning: Language package for $plugin_name is missing."
    else
      echo "Language package for $plugin_name is successfully installed."
    fi
  done
}

# 执行逻辑
process_language_packages
install_lmo_files
validate_language_packages
