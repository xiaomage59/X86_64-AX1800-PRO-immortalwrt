#!/bin/sh

# Patch luci-app-openvpn-server: 禁止重复安装 /etc/config/openvpn
find ./ -type f -name Makefile -path "*/luci-app-openvpn-server/Makefile" | while read MK; do
  echo "Patching $MK"
  sed -i '/INSTALL_CONF.*openvpn.config.*etc\/config\/openvpn/s/^/#/' "$MK"
done

# Patch luci-app-socat: 禁止重复安装 /etc/config/socat
find ./ -type f -name Makefile -path "*/luci-app-socat/Makefile" | while read MK; do
  echo "Patching $MK"
  sed -i '/INSTALL_CONF.*socat.config.*etc\/config\/socat/s/^/#/' "$MK"
done
