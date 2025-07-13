#!/bin/sh

# 以下仅针对 luci-app-store 的makefile （双 “##” 部分）
##SEARCH_ROOT=${1:-.}

##MAKEFILE_PATH=$(find "$SEARCH_ROOT" -type f -path "*/luci-app-store/Makefile" | head -n 1)

##if [ -f "$MAKEFILE_PATH" ]; then
  ##echo "Patching $MAKEFILE_PATH"
  ##sed -i \
    ##-e 's/^\(PKG_VERSION:=\)\([0-9]*\.[0-9]*\.[0-9]*\)-\([0-9]*\)$/\1\2\nPKG_RELEASE:=\3/' \
    ##"$MAKEFILE_PATH"
##else
  ##echo "luci-app-store Makefile not found!"
  ##exit 1
##fi

# 遍历 package 和 feeds 目录下所有 Makefile，修正 PKG_VERSION 和 PKG_RELEASE 格式
##find ./ -type f -name Makefile | while read MKFILE; do
    ##if grep -qE '^PKG_VERSION:=[0-9]+\.[0-9]+\.[0-9]+-[0-9]+' "$MKFILE"; then
        ##echo "Patching version in $MKFILE"
        ##sed -i -E 's/^(PKG_VERSION:=)([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/\1\2\nPKG_RELEASE:=\3/' "$MKFILE"
    ##fi
##done


SEARCH_ROOT=${1:-.}

echo "patch_luci_app_store.sh: searching in $SEARCH_ROOT"

FOUND=0
find "$SEARCH_ROOT" -type f -name Makefile | while read MKFILE; do
    if grep -qE '^PKG_VERSION:=[0-9]+\.[0-9]+\.[0-9]+-[0-9]+' "$MKFILE"; then
        echo "Patching version in $MKFILE"
        sed -i -E 's/^(PKG_VERSION:=)([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/\1\2\nPKG_RELEASE:=\3/' "$MKFILE"
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "No Makefile with PKG_VERSION:=x.y.z-n format found."
fi
