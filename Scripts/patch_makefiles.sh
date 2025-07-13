#!/bin/sh

# Patch luci-app-openvpn-server & luci-app-openvpn: 禁止重复安装 /etc/config/openvpn
for PKGNAME in luci-app-openvpn-server luci-app-openvpn; do
  find ./ -type f -name Makefile -path "*/$PKGNAME/Makefile" | while read MK; do
    echo "Patching $MK"
    sed -i '/INSTALL_CONF.*openvpn.config.*etc\/config\/openvpn/s/^/#/' "$MK"
  done
done

# Patch luci-app-socat: 禁止重复安装 /etc/config/socat
find ./ -type f -name Makefile -path "*/luci-app-socat/Makefile" | while read MK; do
  echo "Patching $MK"
  sed -i '/INSTALL_CONF.*socat.config.*etc\/config\/socat/s/^/#/' "$MK"
done
