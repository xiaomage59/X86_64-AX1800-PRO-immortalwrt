#!/bin/sh

SEARCH_ROOT=${1:-.}

MAKEFILE_PATH=$(find "$SEARCH_ROOT" -type f -path "*/luci-app-store/Makefile" | head -n 1)

if [ -f "$MAKEFILE_PATH" ]; then
  echo "Patching $MAKEFILE_PATH"
  sed -i \
    -e 's/^\(PKG_VERSION:=\)\([0-9]*\.[0-9]*\.[0-9]*\)-\([0-9]*\)$/\1\2\nPKG_RELEASE:=\3/' \
    "$MAKEFILE_PATH"
else
  echo "luci-app-store Makefile not found!"
  exit 1
fi
