#!/bin/bash

# Handles_language.sh: 改进后的语言包处理脚本，确保完整性和对 Compile Firmware 阶段的适配

# Paths
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
INSTALL_RELATIVE_PATH="root/usr/lib/lua/luci/i18n/"
BUILD_LANG_PATH="$PKG_PATH/<plugin>/$INSTALL_RELATIVE_PATH"

# 创建输出目录
mkdir -p "$OUTPUT_PATH"

# 检查 po2lmo 工具是否可用
if ! command -v po2lmo &> /dev/null; then
  echo "Error: po2lmo tool is not installed or not available in PATH."
  exit 1
fi

# 从环境变量中获取插件列表
PLUGIN_LIST=$(echo "$WRT_LIST" | tr ' ' '\n')

# 获取现有语言包列表（从构建目录中获取，而非运行时路径）
EXISTING_LANG_FILES=$(find "$PKG_PATH" -type f -name "*.zh-cn.lmo" -print)
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

      # 安装语言包到插件目录
      install_dir="$plugin_path/$INSTALL_RELATIVE_PATH"
      mkdir -p "$install_dir"
      cp "$OUTPUT_PATH/$lmo_file" "$install_dir"
      echo "Installed $lmo_file to $install_dir"
    done
  done
}

# 验证语言包安装
validate_language_packages() {
  echo "Validating installed language packages..."
  for plugin_name in $PLUGIN_LIST; do
    lmo_file="${plugin_name}.zh-cn.lmo"
    if ! find "$PKG_PATH" -name "$lmo_file" &>/dev/null; then
      echo "Warning: Language package for $plugin_name is missing."
    else
      echo "Language package for $plugin_name is successfully installed."
    fi
  done
}

# 执行逻辑
process_language_packages
validate_language_packages
