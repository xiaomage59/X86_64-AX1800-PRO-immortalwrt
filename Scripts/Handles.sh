#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# 以下处理所有 .po 文件并转换为 .lmo 文件-------2025.04.26

# 检查 po2lmo 工具是否可用
if ! command -v po2lmo &> /dev/null; then
  echo "Error: po2lmo tool is not installed or not available in PATH."
  exit 1
fi

# 递归查找所有 .po 文件并转换为 .zh-cn.lmo 文件
convert_po_to_lmo() {
  echo "Starting selective .po to .lmo conversion for zh-cn..."

  # 遍历所有插件目录，递归查找 .po 文件
  find "$PKG_PATH" -type f -name "*.po" | while read -r po_file; do
    # 获取 .po 文件的基础名称和路径
    po_basename=$(basename "$po_file" .po)
    po_dirname=$(dirname "$po_file")

    # 检查是否是 OpenWrt 标准结构
    if [[ "$po_file" =~ /po/zh-cn/ ]]; then
      echo "Skipping standard OpenWrt structure: $po_file"
      continue
    fi

    # 确定语种后缀
    if [[ "$po_file" =~ zh_CN|zh-cn ]]; then
      lmo_suffix="zh-cn"
    elif [[ "$po_file" =~ zh_Hant|zh-hant|en ]]; then
      echo "Skipping non-zh-cn language file: $po_file"
      continue
    else
      # 无语种标识的情况，按 zh-cn 处理
      lmo_suffix="zh-cn"
    fi

    # 设置生成的 .lmo 文件路径
    lmo_file="/usr/lib/lua/luci/i18n/${po_basename}.${lmo_suffix}.lmo"

    # 检查 .lmo 文件是否已存在，避免覆盖
    if [ ! -f "$lmo_file" ]; then
      echo "Converting $po_file to $lmo_file..."
      po2lmo "$po_file" "$lmo_file"
      
      # 检查转换是否成功
      if [ $? -ne 0 ]; then
        echo "Warning: Failed to convert $po_file to $lmo_file."
        echo "Inspecting file for potential issues..."
        head -n 10 "$po_file" # 输出文件前几行，帮助调试
      fi
    else
      echo "Skipping $po_file, $lmo_file already exists."
    fi
  done

  echo "Selective .po to .lmo conversion completed."
}

# 调用语言包处理函数
convert_po_to_lmo

# 以上处理所有 .po 文件并转换为 .lmo 文件-------2025.04.26

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
