#!/bin/bash
# 全自动语言包处理脚本 - 智能路径检测版

# 动态获取架构
TARGET_ARCH=$(find "$GITHUB_WORKSPACE/wrt/staging_dir" -maxdepth 1 -type d -name "target-*" | head -n1 | xargs basename | sed 's/target-//')
SUBTARGET=$(find "$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH" -maxdepth 1 -type d -name "root-*" | head -n1 | xargs basename | sed 's/root-//')

# 基础语言包目录
BASE_I18N_DIR="$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH/root-$SUBTARGET/usr/lib/lua/luci/i18n"

# 创建日志目录
LOG_DIR="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files"
mkdir -p "$LOG_DIR"

# 主日志配置
MAIN_LOG="$LOG_DIR/language_package_final.log"
exec > >(tee -a "$MAIN_LOG") 2>&1

echo "===== 语言包处理开始 ====="
echo "目标架构: $TARGET_ARCH"
echo "子架构: $SUBTARGET"

# 智能路径分析函数
analyze_plugin_structure() {
    local plugin=$1
    local plugin_dir=$2
    
    # 1. 检查是否存在标准路径
    local std_paths=(
        "luci/apps/${plugin#luci-app-}/i18n"
        "luci/modules/${plugin#luci-app-}/i18n"
        "luci/controller/${plugin#luci-app-}/i18n"
    )
    
    for path in "${std_paths[@]}"; do
        if [ -d "$plugin_dir/$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # 2. 检查Makefile中的路径线索
    if [ -f "$plugin_dir/Makefile" ]; then
        local makefile_path=$(grep -oP 'PO_DIR\s*:?=\s*\K[^\s]+' "$plugin_dir/Makefile" 2>/dev/null)
        if [ -n "$makefile_path" ]; then
            echo "$makefile_path" | sed 's|^\./||'
            return 0
        fi
    fi
    
    # 3. 默认返回标准路径
    echo "luci/apps/${plugin#luci-app-}/i18n"
}

# 核心处理函数
process_plugin() {
    local plugin=$1
    
    # 跳过主题包
    [[ $plugin == luci-theme-* ]] && return 0
    
    # 查找插件目录
    local plugin_dir=$(find "$GITHUB_WORKSPACE/wrt/"{package,feeds} -type d -name "$plugin" -print -quit)
    [ -z "$plugin_dir" ] && return 1
    
    # 查找PO文件
    local po_file=$(find "$plugin_dir" -type f \( -path "*/po/zh-cn/*.po" -o -path "*/po/zh_Hans/*.po" \) -print -quit)
    [ -z "$po_file" ] && po_file=$(find "$plugin_dir" -type f -name "*.po" -print -quit)
    [ -z "$po_file" ] && return 1
    
    # 分析最佳存放路径
    local rel_path=$(analyze_plugin_structure "$plugin" "$plugin_dir")
    local target_dir="$BASE_I18N_DIR/$rel_path"
    mkdir -p "$target_dir"
    
    # 生成lmo文件名
    local base_name=$(sed -E 's/^luci-(app|theme)-//' <<< "$plugin")
    local lmo_file="$target_dir/$base_name.zh-cn.lmo"
    
    # 转换语言包
    if po2lmo "$po_file" "$lmo_file"; then
        echo "[成功] $plugin → ${lmo_file#$BASE_I18N_DIR/}"
        # 记录安装路径
        echo "${lmo_file#$BASE_I18N_DIR/}" >> "$LOG_DIR/installed_paths.txt"
        return 0
    else
        echo "[失败] 转换失败: $po_file"
        rm -f "$lmo_file" 2>/dev/null
        return 1
    fi
}

# 主处理流程
echo "===== 开始处理插件 ====="
> "$LOG_DIR/installed_paths.txt"  # 清空安装路径记录

for plugin in $WRT_LIST; do
    process_plugin "$plugin"
done

# 生成构建系统集成文件
echo "===== 生成构建系统集成文件 ====="
{
    echo "# 自动生成的语言包包含列表"
    echo "# 以下目录需要包含在固件打包系统中"
    echo ""
    sort -u "$LOG_DIR/installed_paths.txt" | while read path; do
        dir=$(dirname "$path")
        echo "staging_dir/i18n_dirs += $dir"
    done
} > "$GITHUB_WORKSPACE/wrt/staging_dir/luci-i18n-dirs.mk"

# 最终验证
echo "===== 安装验证 ====="
find "$BASE_I18N_DIR" -name "*.zh-cn.lmo" > "$LOG_DIR/installed_lmo_files.txt"
echo "已安装语言包数量: $(wc -l < "$LOG_DIR/installed_lmo_files.txt")"
echo "详细清单已保存到: $LOG_DIR/installed_lmo_files.txt"

echo "===== 语言包处理完成 ====="
