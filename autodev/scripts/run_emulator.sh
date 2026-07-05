#!/usr/bin/env bash
# emulator バイナリの低レベルラッパー（通常は start_emulator.sh を使う）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
[ -x "$EMULATOR_BIN" ] || { log_error "emulator が見つかりません。bash setup.sh を実行してください。"; exit 1; }
exec "$EMULATOR_BIN" "$@"
