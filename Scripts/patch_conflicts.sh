#!/bin/sh

# 1. 注释Makefile里的安装命令
for PKGNAME in luci-app-openvpn-server luci-app-openvpn; do
  find . -type f -path "*/$PKGNAME/Makefile" | while read MK; do
    echo "Patching $MK"
    sed -i '/INSTALL_CONF.*openvpn.config.*etc\/config\/openvpn/s/^/#/' "$MK"
    # 删除files/openvpn.config文件（如果存在）
    PKGDIR=$(dirname "$MK")
    if [ -f "$PKGDIR/files/openvpn.config" ]; then
      echo "Removing $PKGDIR/files/openvpn.config"
      rm -f "$PKGDIR/files/openvpn.config"
    fi
  done
done

find . -type f -path "*/luci-app-socat/Makefile" | while read MK; do
  echo "Patching $MK"
  sed -i '/INSTALL_CONF.*socat.config.*etc\/config\/socat/s/^/#/' "$MK"
  PKGDIR=$(dirname "$MK")
  if [ -f "$PKGDIR/files/socat.config" ]; then
    echo "Removing $PKGDIR/files/socat.config"
    rm -f "$PKGDIR/files/socat.config"
  fi
done
