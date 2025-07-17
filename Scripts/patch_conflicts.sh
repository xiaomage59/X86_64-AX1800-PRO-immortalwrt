#!/bin/sh

# 确保在OpenWRT编译根目录执行
if [ ! -d "package" ]; then
    echo "错误：请在OpenWRT编译根目录运行此脚本"
    exit 1
fi

# 修复OpenVPN相关冲突
find package/feeds/luci/luci-app-openvpn* -type f -name "Makefile" | while read MK; do
    echo "处理: $MK"
    PKGDIR=$(dirname "$MK")
    
    # 1. 注释Makefile中的冲突安装命令
    sed -i -e '/INSTALL_.*\/etc\/config\/openvpn/s/^/# /' \
           -e '/INSTALL_.*\/etc\/uci-defaults\/.*openvpn/s/^/# /' \
           "$MK"
    
    # 2. 删除冲突配置文件
    rm -fv "$PKGDIR/files/etc/config/openvpn" 2>/dev/null
    
    # 3. 处理uci-defaults脚本
    find "$PKGDIR/files/etc/uci-defaults" -type f -name "*openvpn*" | while read UCI_SCRIPT; do
        echo "修改uci-defaults脚本: $UCI_SCRIPT"
        sed -i -e '/uci_commit.*openvpn/d' \
               -e '/uci_set.*openvpn/d' \
               -e '/uci_add_section.*openvpn/d' \
               -e '/rm.*\/etc\/config\/openvpn/d' \
               "$UCI_SCRIPT"
    done
    
    # 4. 清理可能残留的配置文件
    find "$PKGDIR/files" -type f -name "*openvpn*" | grep -e "/etc/config/" | while read CFG; do
        echo "删除冲突文件: $CFG"
        rm -f "$CFG"
    done
done

# 修复Socat相关冲突
find package/feeds/luci/luci-app-socat* -type f -name "Makefile" | while read MK; do
    echo "处理: $MK"
    PKGDIR=$(dirname "$MK")
    
    # 1. 注释Makefile中的冲突安装命令
    sed -i -e '/INSTALL_.*\/etc\/config\/socat/s/^/# /' \
           -e '/INSTALL_.*\/etc\/uci-defaults\/.*socat/s/^/# /' \
           "$MK"
    
    # 2. 删除冲突配置文件
    rm -fv "$PKGDIR/files/etc/config/socat" 2>/dev/null
    
    # 3. 处理uci-defaults脚本
    find "$PKGDIR/files/etc/uci-defaults" -type f -name "*socat*" | while read UCI_SCRIPT; do
        echo "修改uci-defaults脚本: $UCI_SCRIPT"
        sed -i -e '/uci_commit.*socat/d' \
               -e '/uci_set.*socat/d' \
               -e '/uci_add_section.*socat/d' \
               -e '/rm.*\/etc\/config\/socat/d' \
               "$UCI_SCRIPT"
    done
done

# 5. 额外清理可能被忽略的路径
for CONF in openvpn socat; do
    find package -path "*/files/etc/config/$CONF" -exec echo "删除: {}" \; -delete 2>/dev/null
    find package -path "*/files/etc/uci-defaults/*$CONF*" -exec echo "检查: {}" \; 
done

echo "修复完成！请执行以下命令确保完全清理："
echo "  make clean"
echo "  rm -rf tmp"
echo "  ./scripts/feeds update -i"
echo "  ./scripts/feeds install -a"
echo "  make menuconfig # 确认配置"
echo "  make -j$(nproc) V=s"
