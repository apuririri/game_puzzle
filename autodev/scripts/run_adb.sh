#!/usr/bin/env bash
# adb 実行ラッパー。素の adb は PreToolUse hook が禁止する。
# 使い方: run_adb.sh [-s <serial>] <args...>（serial 未指定時は $ANDROID_SERIAL → 接続中先頭）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

command -v "$ADB_BIN" >/dev/null 2>&1 || [ -x "$ADB_BIN" ] || { log_error "adb が見つかりません。bash setup.sh を実行してください。"; exit 1; }

# -s 指定が無く、複数デバイス接続時の曖昧さを避けるため自動で -s を付与
if [ "${1:-}" != "-s" ] && [ "$#" -gt 0 ]; then
  case "${1:-}" in
    devices|start-server|kill-server|version|pair|connect|disconnect) exec "$ADB_BIN" "$@" ;;
  esac
  S="$(pick_device "")" || S=""
  if [ -n "$S" ]; then exec "$ADB_BIN" -s "$S" "$@"; fi
fi
exec "$ADB_BIN" "$@"
