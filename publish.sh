#!/bin/sh
# publish.sh
# KernelSU + Magisk module pack script
# Run inside module directory

set -e

MODULE_DIR="$(pwd)"
PARENT_DIR="$(dirname "$MODULE_DIR")"

PROP_FILE="$MODULE_DIR/module.prop"

# ---------- 基础校验 ----------
if [ ! -f "$PROP_FILE" ]; then
    echo "[-] module.prop not found!"
    exit 1
fi

# ---------- 读取模块信息 ----------
MODULE_ID=$(grep '^id=' "$PROP_FILE" | cut -d= -f2)
MODULE_VERSION=$(grep '^version=' "$PROP_FILE" | cut -d= -f2)
MODULE_VERSION_CODE=$(grep '^versionCode=' "$PROP_FILE" | cut -d= -f2)

if [ -z "$MODULE_ID" ] || [ -z "$MODULE_VERSION" ]; then
    echo "[-] Failed to read module info from module.prop"
    exit 1
fi

# ---------- 输出文件名 ----------
ZIP_NAME="${MODULE_ID}-${MODULE_VERSION}.zip"
ZIP_PATH="${PARENT_DIR}/${ZIP_NAME}"

# ---------- 清理旧包 ----------
rm -f "$ZIP_PATH"

echo "[+] Packaging module:"
echo "    ID:      $MODULE_ID"
echo "    Version: $MODULE_VERSION ($MODULE_VERSION_CODE)"
echo "    Output:  $ZIP_PATH"

# ---------- 打包（符合 Magisk + KernelSU 规范） ----------
cd "$MODULE_DIR"
zip -r "$ZIP_PATH" service.sh module.prop adb_port.conf uninstall.sh \
    -x "*.git*" \
    -x "*publish.sh"

echo "[✓] Package created successfully"
