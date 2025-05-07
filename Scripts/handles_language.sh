#!/bin/bash
# 终极语言包处理脚本 - 修复文件名规则和路径搜索问题

# 动态获取架构（兼容多平台）
TARGET_ARCH=$(find "$GITHUB_WORKSPACE/wrt/staging_dir" -maxdepth 1 -type d -name "target-*" | head -n1 | xargs basename | sed 's/target-//')
SUBTARGET=$(find "$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH" -maxdepth 1 -type d -name "root-*" | head -n1 | xargs basename | sed 's/root-//')

# 路径配置（覆盖所有可能的插件位置）
SEARCH_PATHS=(
  "$GITHUB_WORKSPACE/wrt/package"
  "$GITHUB_WORKSPACE/wrt/feeds/luci"
  "$GITHUB_WORKSPACE/wrt/feeds/packages"
  "$GITHUB_WORKSPACE/wrt/package/aliyundrive-webdav/openwrt"  # 第三方插件特殊路径
)

# 目录配置
STAGING_PATH="$GITHUB_WORKSPACE/wrt/staging_dir/target-$TARGET_ARCH/root-$SUBTARGET/usr/lib/lua/luci/i18n"
LOG_DIR="$GITHUB_WORKSPACE/wrt/build_dir/target-lmo-files"
MAIN_LOG="$LOG_DIR/language_package_main.log"
PLUGIN_LOG_DIR="$LOG_DIR/plugin_logs"

# 初始化环境
mkdir -p "$STAGING_PATH" "$PLUGIN_LOG_DIR"
echo "=== Language Package Processor ===" > "$MAIN_LOG"
echo "Target: $TARGET_ARCH | Subtarget: $SUBTARGET" >> "$MAIN_LOG"
echo "Staging Path: $STAGING_PATH" >> "$MAIN_LOG"

# 工具检查
if ! command -v po2lmo &> /dev/null; then
  echo "ERROR: po2lmo not found. Install with: sudo apt install po4a" | tee -a "$MAIN_LOG"
  exit 1
fi

# 核心函数：生成正确的.lmo文件名
generate_lmo_name() {
  local plugin_name=$1
  # 转换规则：
  # luci-app-xxx → xxx.zh-cn.lmo
  # luci-theme-yyy → yyy.zh-cn.lmo
  echo "$plugin_name" | sed -E 's/^luci-(app|theme)-//'
}

# 核心函数：查找插件真实路径
find_plugin_path() {
  local plugin_name=$1
  for base_path in "${SEARCH_PATHS[@]}"; do
    # 宽松匹配目录（兼容带/不带luci-前缀的情况）
    found_path=$(find "$base_path" -type d -iname "*${plugin_name#luci-}*" -print -quit 2>/dev/null)
    [ -n "$found_path" ] && echo "$found_path" && return 0
  done
  echo ""
}

# 主处理流程
process_plugins() {
  echo "=== Processing Plugins ===" >> "$MAIN_LOG"
  
  # 获取已有语言包（用于去重）
  existing_packs=$(find "$STAGING_PATH" -name "*.zh-cn.lmo" -exec basename {} \; | sed 's/.zh-cn.lmo//')

  for plugin in $WRT_LIST; do
    plugin_log="$PLUGIN_LOG_DIR/${plugin}.log"
    echo "Plugin: $plugin" > "$plugin_log"
    
    # 查找插件路径
    plugin_path=$(find_plugin_path "$plugin")
    if [ -z "$plugin_path" ]; then
      echo "WARNING: Directory not found for $plugin" | tee -a "$MAIN_LOG" "$plugin_log"
      continue
    fi
    echo "Found at: $plugin_path" >> "$plugin_log"

    # 生成目标文件名（不带app-/theme-前缀）
    lmo_name=$(generate_lmo_name "$plugin")
    lmo_file="$STAGING_PATH/${lmo_name}.zh-cn.lmo"

    # 跳过已存在的语言包
    if echo "$existing_packs" | grep -q "^${lmo_name}$"; then
      echo "SKIPPED: Language pack already exists ($lmo_name.zh-cn.lmo)" >> "$plugin_log"
      continue
    fi

    # 查找并转换.po文件（优先zh-cn，其次zh_Hans）
    po_file=$(find "$plugin_path" -type f \( -path "*/po/zh-cn/*.po" -o -path "*/po/zh_Hans/*.po" \) -print -quit)
    if [ -z "$po_file" ]; then
      echo "ERROR: No .po file found for $plugin" | tee -a "$MAIN_LOG" "$plugin_log"
      continue
    fi

    # 执行转换
    echo "Converting: $po_file → $lmo_file" >> "$plugin_log"
    if po2lmo "$po_file" "$lmo_file"; then
      echo "SUCCESS: Generated $lmo_name.zh-cn.lmo" | tee -a "$MAIN_LOG" "$plugin_log"
      existing_packs="$existing_packs $lmo_name"  # 添加到已处理列表
    else
      echo "ERROR: Failed to convert $po_file" | tee -a "$MAIN_LOG" "$plugin_log"
    fi
  done
}

# 验证结果
validate_results() {
  echo "=== Validation ===" >> "$MAIN_LOG"
  all_success=true

  for plugin in $WRT_LIST; do
    lmo_name=$(generate_lmo_name "$plugin")
    lmo_file="$STAGING_PATH/${lmo_name}.zh-cn.lmo"

    if [ -f "$lmo_file" ]; then
      echo "PASS: $plugin → $lmo_name.zh-cn.lmo" >> "$MAIN_LOG"
    else
      echo "FAIL: $plugin missing language pack (expected: $lmo_name.zh-cn.lmo)" >> "$MAIN_LOG"
      all_success=false
    fi
  done

  $all_success && echo "ALL LANGUAGE PACKS VALIDATED" >> "$MAIN_LOG" || echo "SOME LANGUAGE PACKS MISSING" >> "$MAIN_LOG"
}

# 执行流程
process_plugins
validate_results

# 打印主日志（用于CI显示）
cat "$MAIN_LOG"
