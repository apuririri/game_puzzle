#!/usr/bin/env bash
# AVD 起動（boot 完了待ち + UIテスト安定化まで / 修正方針 §3-2）。
# 使い方: start_emulator.sh [AVD名]（省略時 android_env.yaml::avd.name）
#  - 既定 headless（-no-window）。HEADFUL=1 で GUI 表示。
#  - KVM 不可時は allow_no_accel:true なら -no-accel で続行（低速警告）。
#  - 起動済みなら何もしない（冪等）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

AVD="${1:-$(aconf avd.name autodev_api35)}"
BOOT_TIMEOUT="$(aconf emulator.boot_timeout_sec 180)"
GPU="$(aconf emulator.gpu swiftshader_indirect)"
HEADLESS="$(aconf emulator.headless true)"
[ "${HEADFUL:-0}" = "1" ] && HEADLESS=false

[ -x "$EMULATOR_BIN" ] || { log_error "emulator 未導入。bash setup.sh を実行してください。"; exit 1; }
"$EMULATOR_BIN" -list-avds 2>/dev/null | grep -qx "$AVD" || { log_error "AVD '$AVD' が存在しません。setup_android_env.sh で作成してください。"; exit 1; }

# 既に起動済みの emulator があるか
RUNNING="$(adb_devices | grep '^emulator-' | head -1 || true)"
if [ -n "$RUNNING" ] && wait_boot "$RUNNING" 5; then
  log_info "起動済みエミュレータを利用: $RUNNING"
  stabilize_device "$RUNNING"
  echo "$RUNNING"
  exit 0
fi

ARGS=(-avd "$AVD" -gpu "$GPU" -no-snapshot-save -no-boot-anim -no-audio)
[ "$HEADLESS" = "true" ] && ARGS+=(-no-window)
if [ "$AUTODEV_OS" = "linux" ] && [ ! -w /dev/kvm ]; then
  if [ "$(aconf emulator.allow_no_accel true)" = "true" ]; then
    log_warn "/dev/kvm が利用できません。-no-accel で続行します（非常に低速）。KVM 設定を推奨。"
    ARGS+=(-no-accel)
  else
    log_error "/dev/kvm が利用できません（allow_no_accel=false）。KVM を設定してください。"
    exit 1
  fi
fi

LOG="$(log_dir)/emulator_$(date +%H%M%S).log"
log_info "エミュレータ起動: $AVD (headless=$HEADLESS, gpu=$GPU, log=${LOG#$REPO_ROOT/})"
nohup "$EMULATOR_BIN" "${ARGS[@]}" >"$LOG" 2>&1 &
EMU_PID=$!

# serial 出現 + boot 完了待ち
i=0; SERIAL=""
while [ "$i" -lt "$BOOT_TIMEOUT" ]; do
  SERIAL="$(adb_devices | grep '^emulator-' | head -1 || true)"
  [ -n "$SERIAL" ] && break
  kill -0 "$EMU_PID" 2>/dev/null || { log_error "エミュレータプロセスが終了しました。ログ: $LOG"; tail -20 "$LOG" >&2; exit 1; }
  sleep 2; i=$((i+2))
done
[ -z "$SERIAL" ] && { log_error "エミュレータが adb に現れません（${BOOT_TIMEOUT}s）。ログ: $LOG"; exit 1; }
if ! wait_boot "$SERIAL" "$BOOT_TIMEOUT"; then
  log_error "boot 完了待ちタイムアウト（${BOOT_TIMEOUT}s）。ログ: $LOG"
  exit 1
fi
stabilize_device "$SERIAL"
log_info "エミュレータ起動完了: $SERIAL"
echo "$SERIAL"
