#!/usr/bin/env bash
# 最頻出の直列実行: ビルド → インストール → 起動。使い方: build_install_run.sh [debug|release] [serial]
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
BT="${1:-debug}"; SERIAL="${2:-}"
APK="$("$SCRIPTS_DIR/build.sh" "$BT" | tail -1)" || exit 1
"$SCRIPTS_DIR/install.sh" "$APK" "$SERIAL" || exit 1
"$SCRIPTS_DIR/run.sh" "$SERIAL" || exit 1
log_info "build → install → run 完了"
