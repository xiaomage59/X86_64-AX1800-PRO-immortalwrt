#!/bin/sh

# 注释Makefile里的安装命令，并递归删除files目录下所有openvpn/socat config
for PKGNAME in luci-app-openvpn-server luci-app-openvpn; do
  find . -type f -path "*/$PKGNAME/Makefile" | while read MK; do
    echo "Patching $MK"
    sed -i '/INSTALL_CONF.*openvpn.config.*etc\/config\/openvpn/s/^/#/' "$MK"
    PKGDIR=$(dirname "$MK")
    # 递归删除所有与openvpn相关的config
    find "$PKGDIR/files" -type f \( -name "openvpn.config" -o -name "openvpn" \) 2>/dev/null | while read CFG; do
      echo "Removing $CFG"
      rm -f "$CFG"
    done
    # 删除files/etc/config/openvpn（如果有）
    if [ -f "$PKGDIR/files/etc/config/openvpn" ]; then
      echo "Removing $PKGDIR/files/etc/config/openvpn"
      rm -f "$PKGDIR/files/etc/config/openvpn"
    fi
  done
done

find . -type f -path "*/luci-app-socat/Makefile" | while read MK; do
  echo "Patching $MK"
  sed -i '/INSTALL_CONF.*socat.config.*etc\/config\/socat/s/^/#/' "$MK"
  PKGDIR=$(dirname "$MK")
  # 递归删除所有与socat相关的config
  find "$PKGDIR/files" -type f \( -name "socat.config" -o -name "socat" \) 2>/dev/null | while read CFG; do
    echo "Removing $CFG"
    rm -f "$CFG"
  done
  # 删除files/etc/config/socat（如果有）
  if [ -f "$PKGDIR/files/etc/config/socat" ]; then
    echo "Removing $PKGDIR/files/etc/config/socat"
    rm -f "$PKGDIR/files/etc/config/socat"
  fi
done
