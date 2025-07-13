#!/bin/bash

# 遍历 package 和 feeds 目录下所有 Makefile
find ./ -type f -name Makefile | while read MKFILE; do
    # 检查是否包含不规范的 PKG_VERSION (比如有"-"号)
    if grep -qE '^PKG_VERSION:=[0-9]+\.[0-9]+\.[0-9]+-[0-9]+' "$MKFILE"; then
        echo "Patching version in $MKFILE"
        # 提取主版本和release号
        sed -i -E 's/^(PKG_VERSION:=)([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/\1\2\nPKG_RELEASE:=\3/' "$MKFILE"
    fi
done
