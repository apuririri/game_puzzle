#!/usr/bin/env bash
# アプリ起動 + 起動確認。使い方: run.sh [serial]
# launcher intent で起動し、プロセス出現と logcat の APP_STARTED マーカーを確認する。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

S="$(device_required "${1:-}")" || exit 1
"$ADB_BIN" -s "$S" logcat -c 2>/dev/null || true
log_info "アプリ起動: $APP_ID → $S"
"$ADB_BIN" -s "$S" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
  || { log_error "起動失敗（インストール済みか確認: install.sh）"; exit 1; }

# プロセス出現待ち（10s）
i=0; PID=""
while [ "$i" -lt 10 ]; do
  PID="$(app_pid "$S")"; [ -n "$PID" ] && break
  sleep 1; i=$((i+1))
done
[ -z "$PID" ] && { log_error "アプリプロセスが起動しません ($APP_ID)"; exit 1; }

# 起動マーカー確認（healthcheck 相当 / 修正方針 §3-4。雛形は AppLog: APP_STARTED を出す）
sleep 2
if "$ADB_BIN" -s "$S" logcat -d --pid "$PID" 2>/dev/null | grep -q "APP_STARTED"; then
  log_info "起動確認 OK（pid=$PID, APP_STARTED マーカー検出）"
else
  log_warn "APP_STARTED マーカー未検出（pid=$PID は起動中）。AppLogger の起動ログを確認してください。"
fi
exit 0
