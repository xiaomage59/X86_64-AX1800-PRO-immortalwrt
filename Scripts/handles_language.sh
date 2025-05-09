#!/bin/bash
# 语言包处理脚本 - 路径优化版

# 动态获取架构
TARGET_ARCH=$(find "$GITHUB_WORKSPACE/wrt/staging_dir" -maxdepth 1 -type d -name "target-*" | head -n1 | xargs basename | sed 's/target-//')
SUBTARGET=$(find "$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH" -maxdepth 1 -type d -name "root-*" | head -n1 | xargs basename | sed 's/root-//')

# 基础语言包目录
BASE_I18N_DIR="$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH/root-$SUBTARGET/usr/lib/lua/luci/i18n"

# 特殊路径映射表
declare -A SPECIAL_PATHS=(
    ["luci-app-store"]="luci/apps/store/i18n"
    ["luci-app-quickstart"]="luci/apps/quickstart/i18n"
    ["luci-app-unishare"]="luci/apps/unishare/i18n"
    ["luci-app-linkease"]="luci/apps/linkease/i18n"
)

# 创建日志目录
LOG_DIR="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files"
mkdir -p "$LOG_DIR"

# 主日志配置
MAIN_LOG="$LOG_DIR/language_package_final.log"
exec > >(tee -a "$MAIN_LOG") 2>&1

echo "===== 语言包处理开始 ====="
echo "目标架构: $TARGET_ARCH"
echo "子架构: $SUBTARGET"

# 核心处理函数
process_plugin() {
    local plugin=$1
    local plugin_dir=$2
    local po_file=$3
    
    # 获取基础名称
    local base_name=$(sed -E 's/^luci-(app|theme)-//' <<< "$plugin")
    
    # 确定目标目录
    local target_dir="$BASE_I18N_DIR"
    if [[ -n "${SPECIAL_PATHS[$plugin]}" ]]; then
        target_dir="$BASE_I18N_DIR/${SPECIAL_PATHS[$plugin]}"
        mkdir -p "$target_dir"
    fi

    local lmo_file="$target_dir/$base_name.zh-cn.lmo"
    
    # 转换语言包
    if po2lmo "$po_file" "$lmo_file"; then
        echo "[成功] $plugin → ${lmo_file#$BASE_I18N_DIR/}"
        return 0
    else
        echo "[失败] 转换失败: $po_file"
        rm -f "$lmo_file" 2>/dev/null
        return 1
    fi
}

# 查找PO文件
find_po_file() {
    local dir=$1
    local po_file=$(find "$dir" -type f \( -path "*/po/zh-cn/*.po" -o -path "*/po/zh_Hans/*.po" \) -print -quit)
    [ -z "$po_file" ] && po_file=$(find "$dir" -type f -name "*.po" -print -quit)
    echo "$po_file"
}

# 主处理流程
echo "===== 开始处理插件 ====="
declare -A processed_plugins
for plugin in $WRT_LIST; do
    # 跳过主题包
    [[ $plugin == luci-theme-* ]] && continue
    
    # 查找插件目录
    plugin_dir=$(find "$GITHUB_WORKSPACE/wrt/"{package,feeds} -type d -name "$plugin" -print -quit)
    [ -z "$plugin_dir" ] && continue
    
    # 查找PO文件
    po_file=$(find_po_file "$plugin_dir")
    [ -z "$po_file" ] && continue

    # 处理插件
    if process_plugin "$plugin" "$plugin_dir" "$po_file"; then
        processed_plugins["$plugin"]=1
    fi
done

# 生成路径验证报告
echo "===== 路径验证报告 ====="
for plugin in "${!processed_plugins[@]}"; do
    base_name=$(sed -E 's/^luci-(app|theme)-//' <<< "$plugin")
    if [[ -n "${SPECIAL_PATHS[$plugin]}" ]]; then
        lmo_path="$BASE_I18N_DIR/${SPECIAL_PATHS[$plugin]}/$base_name.zh-cn.lmo"
    else
        lmo_path="$BASE_I18N_DIR/$base_name.zh-cn.lmo"
    fi
    
    if [ -f "$lmo_path" ]; then
        echo "[验证通过] $plugin → $lmo_path"
    else
        echo "[验证失败] $plugin → 文件未找到"
    fi
done

# 生成安装清单
find "$BASE_I18N_DIR" -name "*.zh-cn.lmo" > "$LOG_DIR/installed_lmo_files.txt"
echo "===== 已安装语言包清单 ====="
cat "$LOG_DIR/installed_lmo_files.txt"

# 生成构建系统提示文件
echo "===== 构建系统提示 ====="
echo "以下路径需要包含在固件打包过程中："
find "$BASE_I18N_DIR" -type d | sed "s|$BASE_I18N_DIR||" > "$LOG_DIR/directory_include.txt"
cat "$LOG_DIR/directory_include.txt"
