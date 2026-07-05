#!/usr/bin/env bash
# デバイス共通関数（_servers.sh の後継 / 修正方針 §6-4）。source して使う。
# 前提: _common.sh を先に source していること。

# 接続中デバイスの serial 一覧（state=device のみ）
adb_devices() { "$ADB_BIN" devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}'; }

# デバイス解決の優先順: $1 引数 > $ANDROID_SERIAL > 接続中の先頭デバイス
pick_device() {
  local want="${1:-${ANDROID_SERIAL:-}}"
  if [ -n "$want" ]; then
    adb_devices | grep -qx "$want" && { echo "$want"; return 0; }
    return 1
  fi
  adb_devices | head -1
}

# デバイス必須（fallback 禁止原則: 未接続は明確な FAIL）
device_required() {  # device_required [serial] → SERIAL を echo
  local s
  s="$(pick_device "${1:-}")" || s=""
  if [ -z "$s" ]; then
    log_error "接続中の device/emulator がありません（adb devices）。"
    log_error "エミュレータ: autodev/scripts/start_emulator.sh / 実機: USB 接続+USBデバッグ許可を確認。"
    return 1
  fi
  echo "$s"
}

# boot 完了待ち
wait_boot() {  # wait_boot <serial> <timeout_sec>
  local s="$1" t="${2:-180}" i=0
  "$ADB_BIN" -s "$s" wait-for-device 2>/dev/null || true
  while [ "$i" -lt "$t" ]; do
    if [ "$("$ADB_BIN" -s "$s" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
      return 0
    fi
    sleep 2; i=$((i+2))
  done
  return 1
}

# UIテスト安定化: アニメーション無効化 + 画面ON（修正方針 §7-5）
stabilize_device() {  # stabilize_device <serial>
  local s="$1"
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    "$ADB_BIN" -s "$s" shell settings put global "$k" 0 >/dev/null 2>&1 || true
  done
  "$ADB_BIN" -s "$s" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$s" shell input keyevent 82 >/dev/null 2>&1 || true
}

# アプリの pid（未起動なら空）
app_pid() {  # app_pid <serial> [app_id]
  "$ADB_BIN" -s "$1" shell pidof -s "${2:-$APP_ID}" 2>/dev/null | tr -d '\r'
}

# logcat ダンプ（アプリ起動中は pid で絞り込み）→ 出力先パスを echo
dump_logcat() {  # dump_logcat <serial> <out_file> [app_id]
  local s="$1" out="$2" id="${3:-$APP_ID}" pid
  mkdir -p "$(dirname "$out")"
  pid="$(app_pid "$s" "$id")"
  if [ -n "$pid" ]; then
    "$ADB_BIN" -s "$s" logcat -d --pid "$pid" > "$out" 2>/dev/null || "$ADB_BIN" -s "$s" logcat -d > "$out"
  else
    "$ADB_BIN" -s "$s" logcat -d > "$out"
  fi
  echo "$out"
}

# logcat のクラッシュ痕跡スキャン（検出で 1 を返す）
scan_logcat_crash() {  # scan_logcat_crash <logcat_file> （クラッシュ痕跡があれば内容を表示して 1 を返す）
  if grep -E "FATAL EXCEPTION|AndroidRuntime: FATAL|Process .* has died|ANR in " "$1" 2>/dev/null; then
    return 1
  fi
  return 0
}

# APK パス解決
apk_path() {  # apk_path <debug|release>
  local bt="${1:-debug}"
  if [ "$bt" = "release" ]; then
    echo "$APP_DIR/build/outputs/apk/release/app-release.apk"
  else
    echo "$APP_DIR/build/outputs/apk/debug/app-debug.apk"
  fi
}
