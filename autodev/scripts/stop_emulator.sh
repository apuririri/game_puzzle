#!/usr/bin/env bash
# 起動中の全エミュレータを停止する。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
FOUND=0
for s in $(adb_devices | grep '^emulator-' || true); do
  log_info "エミュレータ停止: $s"
  "$ADB_BIN" -s "$s" emu kill >/dev/null 2>&1 || true
  FOUND=1
done
[ "$FOUND" = "0" ] && log_info "起動中のエミュレータはありません。"
exit 0
