#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#--------------------以下2025.04.29测试语言包-----------------------#

# Paths
OUTPUT_PATH="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files/"
INSTALL_DIR_ROOT="/usr/lib/lua/luci/i18n/"

# 创建输出目录
mkdir -p "$OUTPUT_PATH"

# 检查 po2lmo 工具是否可用
if ! command -v po2lmo &> /dev/null; then
  echo "Error: po2lmo tool is not installed or not available in PATH."
  exit 1
fi

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

  # 检查目标路径中是否存在 .lmo 文件
  if [ ! -f "$PKG_PATH/$plugin_name/root$INSTALL_DIR_ROOT/$lmo_basename" ]; then
    return 0  # 语言包缺失
  else
    return 1  # 语言包已存在
  fi
}

# 按需转换 .po 文件为 .lmo 文件
convert_po_to_lmo() {
  local po_file="$1"
  local lmo_file="$2"

  echo "Converting $po_file to $lmo_file..."
  po2lmo "$po_file" "$lmo_file"

  # 检查转换是否成功
  if [ $? -ne 0 ]; then
    echo "Warning: Failed to convert $po_file to $lmo_file."
  fi
}

# 处理语言包
process_language_packages() {
  echo "Starting selective .po to .lmo conversion for zh-cn..."

  # 遍历插件目录中的所有 .po 文件
  find "$PKG_PATH" -type f -name "*.po" | while read -r po_file; do
    # 获取插件名称
    plugin_name=$(echo "$po_file" | awk -F/ '{print $(NF-3)}')

    # 获取 .po 文件的基础名称和语言后缀
    po_basename=$(basename "$po_file" .po)
    lmo_suffix=$(get_language_suffix "$po_file")

    if [[ "$lmo_suffix" == "skip" ]]; then
      echo "Skipping non-zh-cn language file: $po_file"
      continue
    fi

    # 设置生成的 .lmo 文件路径
    lmo_file="${OUTPUT_PATH}${po_basename}.${lmo_suffix}.lmo"

    # 仅在目标路径中缺少语言包时进行处理
    if is_language_missing "$plugin_name" "${po_basename}.${lmo_suffix}.lmo"; then
      convert_po_to_lmo "$po_file" "$lmo_file"
    else
      echo "Skipping $po_file, language package already exists for $plugin_name"
    fi
  done

  echo "Selective .po to .lmo conversion completed."
}

# 遍历生成的 .lmo 文件并安装到目标路径
install_lmo_files() {
  echo "Installing .lmo files to target directories..."

  find "$OUTPUT_PATH" -type f -name "*.lmo" | while read -r lmo_file; do
    # 获取插件名称
    plugin_name=$(basename "$lmo_file" .zh-cn.lmo)

    # 确定目标路径
    install_path="$PKG_PATH/$plugin_name/root$INSTALL_DIR_ROOT"
    mkdir -p "$install_path"

    # 检查目标路径是否需要安装
    if [ ! -f "$install_path/$(basename "$lmo_file")" ] || [ "$lmo_file" -nt "$install_path/$(basename "$lmo_file")" ]; then
      echo "Installing $lmo_file to $install_path..."
      cp "$lmo_file" "$install_path"
    else
      echo "Skipping $lmo_file, already up-to-date in $install_path"
    fi
  done

  echo "All .lmo files have been installed to their respective plugin directories."
}

# 主逻辑：确保语言包处理在插件编译完成后执行
echo "Waiting for all plugins to finish compilation..."
# 此处可以加入检查编译状态的逻辑，例如等待编译完成标志文件
# sleep 30  # 示例：等待编译完成

process_language_packages
install_lmo_files

#--------------------以上2025.04.29测试语言包-----------------------#

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	cd ./luci-theme-argon/

	sed -i "/font-weight:/ { /important/! { /\/\*/! s/:.*/: var(--font-weight);/ } }" $(find ./luci-theme-argon -type f -iname "*.css")
	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#移除Shadowsocks组件
PW_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile")
if [ -f "$PW_FILE" ]; then
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' $PW_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' $PW_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $PW_FILE

	cd $PKG_PATH && echo "passwall has been fixed!"
fi

SP_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-ssr-plus/Makefile")
if [ -f "$SP_FILE" ]; then
	sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' $SP_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' $SP_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $SP_FILE

	cd $PKG_PATH && echo "ssr-plus has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Coremark编译失败
CM_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/coremark/Makefile")
if [ -f "$CM_FILE" ]; then
	sed -i 's/mkdir/mkdir -p/g' $CM_FILE

	cd $PKG_PATH && echo "coremark has been fixed!"
fi
