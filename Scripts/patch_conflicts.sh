#!/bin/sh

# 修复OpenVPN相关冲突
find . -type f -path "*/luci-app-openvpn*/Makefile" | while read MK; do
    echo "彻底修复: $MK"
    PKGDIR=$(dirname "$MK")
    
    # 1. 注释所有可能安装冲突配置的Makefile命令（扩展匹配模式）
    sed -i -e '/INSTALL_CONF.*\/etc\/config\/openvpn/s/^/# /' \
           -e '/INSTALL_DATA.*\/etc\/config\/openvpn/s/^/# /' \
           -e '/cp.*\/etc\/config\/openvpn/s/^/# /' \
           "$MK"

    # 2. 深度清理所有相关配置文件
    find "$PKGDIR" -type f \( \
        -name "openvpn.config" \
        -o -name "openvpn" \
        -o -path "*/files/etc/config/openvpn" \
        -o -path "*/files/etc/uci-defaults/*openvpn*" \
    \) -exec echo "删除: {}" \; -exec rm -f {} \;
done

# 修复Socat相关冲突
find . -type f -path "*/luci-app-socat*/Makefile" | while read MK; do
    echo "彻底修复: $MK"
    PKGDIR=$(dirname "$MK")
    
    # 1. 注释所有可能安装冲突配置的Makefile命令
    sed -i -e '/INSTALL_CONF.*\/etc\/config\/socat/s/^/# /' \
           -e '/INSTALL_DATA.*\/etc\/config\/socat/s/^/# /' \
           -e '/cp.*\/etc\/config\/socat/s/^/# /' \
           "$MK"

    # 2. 深度清理所有相关配置文件
    find "$PKGDIR" -type f \( \
        -name "socat.config" \
        -o -name "socat" \
        -o -path "*/files/etc/config/socat" \
        -o -path "*/files/etc/uci-defaults/*socat*" \
    \) -exec echo "删除: {}" \; -exec rm -f {} \;
done

# 3. 额外处理可能被遗漏的安装机制
find . -type f -path "*/luci-app-*/Makefile" -exec grep -q "openvpn\|socat" {} \; -print | while read MK; do
    echo "检查潜在冲突: $MK"
    sed -i -e '/INSTALL_.*[\/ ]etc\/config\/openvpn/s/^/# /' \
           -e '/INSTALL_.*[\/ ]etc\/config\/socat/s/^/# /' \
           "$MK"
done

echo "修复完成！请清除编译缓存后重新编译："
echo "  make clean && make dirclean"
echo "  make -j$(nproc) V=s"
