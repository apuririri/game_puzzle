#!/usr/bin/env bash
# APK インストール。使い方: install.sh [apkパス] [serial]（既定: debug APK / 自動選択デバイス）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

APK="${1:-$(apk_path debug)}"
[ -f "$APK" ] || { log_error "APK がありません: $APK（先に build.sh を実行）"; exit 1; }
S="$(device_required "${2:-}")" || exit 1
log_info "install -r ${APK#$REPO_ROOT/} → $S"
"$ADB_BIN" -s "$S" install -r "$APK" || { log_error "インストール失敗（署名不一致なら uninstall.sh 後に再実行）"; exit 1; }
log_info "インストール完了 ($APP_ID)"
