#!/bin/bash

# Handles_language.sh: 改进后的语言包处理脚本
echo "Starting selective .po to .lmo conversion for zh-cn..."

# Paths
PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
INSTALL_DIR_ROOT="/usr/lib/lua/luci/i18n/"

# 创建输出目录
mkdir -p "$OUTPUT_PATH"

# 检查 po2lmo 工具是否可用
if ! command -v po2lmo &> /dev/null; then
  echo "Error: po2lmo tool is not installed or not available in PATH."
  exit 1
fi

# 从环境变量中获取插件列表
PLUGIN_LIST=$(echo "$WRT_LIST" | tr ' ' '\n')

# 获取语言包文件的语种
get_language_suffix() {
  local po_file="$1"
  if [[ "$po_file" =~ zh_CN|zh-cn ]]; then
    echo "zh-cn"
  elif [[ "$po_file" =~ zh_Hans ]]; then
    echo "zh-cn"
  elif [[ "$po_file" =~ zh_Hant|en ]]; then
    echo "skip" # 非中文，直接跳过
  else
    echo "zh-cn" # 无明确语种标识，默认为 zh-cn
  fi
}

# 检查插件目标路径中是否缺少语言包
is_language_missing() {
  local plugin_name="$1"
  local lmo_basename="$2"

  # 检查插件的语言包目录是否存在
  if [ ! -d "$PKG_PATH/$plugin_name/root$INSTALL_DIR_ROOT" ]; then
    return 0  # 语言包目录不存在，视为语言包缺失
  fi

  # 检查 .lmo 文件是否已存在
  if [ ! -f "$PKG_PATH/$plugin_name/root$INSTALL_DIR_ROOT/$lmo_basename" ]; then
    return 0  # 语言包缺失
  else
    return 1  # 语言包已存在
  fi
}

# 转换 .po 文件为 .lmo 文件
convert_po_to_lmo() {
  local po_file="$1"
  local lmo_file="$2"

  # 检查 .lmo 文件是否已经存在且是最新的
  if [ -f "$lmo_file" ] && [ "$po_file" -ot "$lmo_file" ]; then
    echo "Skipping $po_file, .lmo file is already up-to-date."
    return
  fi

  echo "Converting $po_file to $lmo_file..."
  po2lmo "$po_file" "$lmo_file"

  # 检查转换是否成功
  if [ $? -ne 0 ]; then
    echo "Warning: Failed to convert $po_file to $lmo_file."
  fi
}

# 遍历插件列表并处理语言包
process_language_packages() {
  echo "Processing .po files to .lmo for zh-cn..."

  for plugin_name in $PLUGIN_LIST; do
    plugin_path=$(find "$PKG_PATH" -type d -name "$plugin_name" -print -quit)
    if [ -z "$plugin_path" ]; then
      echo "Plugin $plugin_name not found in package directory. Skipping..."
      continue
    fi

    find "$plugin_path" -type f -name "*.po" | while read -r po_file; do
      po_basename=$(basename "$po_file" .po)
      lmo_suffix=$(get_language_suffix "$po_file")

      if [[ "$lmo_suffix" == "skip" ]]; then
        echo "Skipping non-zh-cn language file: $po_file"
        continue
      fi

      lmo_file="${OUTPUT_PATH}${po_basename}.${lmo_suffix}.lmo"
      if is_language_missing "$plugin_name" "${po_basename}.${lmo_suffix}.lmo"; then
        convert_po_to_lmo "$po_file" "$lmo_file"
      else
        echo "Skipping $po_file, language package already exists for $plugin_name"
      fi
    done
  done
}

# 安装 .lmo 文件
install_lmo_files() {
  echo "Installing .lmo files to target directories..."

  find "$OUTPUT_PATH" -type f -name "*.lmo" | while read -r lmo_file; do
    plugin_name=$(basename "$lmo_file" .zh-cn.lmo)
    install_path="$PKG_PATH/$plugin_name/root$INSTALL_DIR_ROOT"
    mkdir -p "$install_path"

    if [ ! -f "$install_path/$(basename "$lmo_file")" ] || [ "$lmo_file" -nt "$install_path/$(basename "$lmo_file")" ]; then
      echo "Installing $lmo_file to $install_path..."
      cp "$lmo_file" "$install_path"
    else
      echo "Skipping $lmo_file, already up-to-date in $install_path"
    fi
  done

  echo "All .lmo files have been installed to their respective plugin directories."
}

# 主逻辑
process_language_packages
install_lmo_files
