#!/usr/bin/env bash
# アプリのアンインストール（クリーンインストール検証・署名不一致解消用。アプリデータは消える）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
S="$(device_required "${1:-}")" || exit 1
"$ADB_BIN" -s "$S" uninstall "$APP_ID" || { log_warn "アンインストール失敗（未インストールの可能性）"; exit 0; }
log_info "アンインストール完了 ($APP_ID)"
