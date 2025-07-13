#!/bin/sh

# 假设 luci-app-store 已经被拉取到 package/luci-app-store 或 feeds/luci/luci-app-store
MAKEFILE_PATH=$(find ./ -type f -path "*/luci-app-store/Makefile" | head -n 1)

if [ -f "$MAKEFILE_PATH" ]; then
  echo "Patching $MAKEFILE_PATH"
  # 替换 PKG_VERSION 和 PKG_RELEASE 的写法
  sed -i \
    -e 's/^\(PKG_VERSION:=\)\([0-9]*\.[0-9]*\.[0-9]*\)-\([0-9]*\)$/\1\2\nPKG_RELEASE:=\3/' \
    "$MAKEFILE_PATH"
else
  echo "luci-app-store Makefile not found!"
  exit 1
fi