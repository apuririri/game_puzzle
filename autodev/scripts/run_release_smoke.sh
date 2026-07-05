#!/usr/bin/env bash
# S14 RG2 リリース署名済み APK の本番想定スモーク（FR-5.19.3）。
# build.sh release で生成された署名済み APK を実機（または HEADFUL emulator）に
# クリーンインストール → run_smoke_device.sh + 全 maestro flow + logcat クラッシュスキャン。
#
# 使い方:
#   run_release_smoke.sh                 # release.yaml::release_smoke_target に従う
#   run_release_smoke.sh --target device # 実機
#   run_release_smoke.sh --target emulator
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

CONF="$AUTODEV_DIR/config/release.yaml"
TARGET="$(conf_get "$CONF" release_smoke_target "emulator")"
TIMEOUT_SEC="$(conf_get "$CONF" release_smoke_timeout_sec 1800)"
EVIDENCE_OUT="$REPO_ROOT/$(conf_get "$CONF" evidence_dir "autodev/evidence/_release")"

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    *) echo "[FAIL] 不明な引数: $1"; exit 2 ;;
  esac
done

mkdir -p "$EVIDENCE_OUT/screenshots" "$EVIDENCE_OUT/logcat"

# 1) リリース APK ビルド（既存なら再利用しない: 必ず最新で確認）
log_info "build.sh release を実行..."
RELEASE_APK="$("$SCRIPTS_DIR/build.sh" release | tail -1)"
[ -f "$RELEASE_APK" ] || { log_error "release APK が生成されませんでした"; exit 1; }
log_info "release APK: ${RELEASE_APK#$REPO_ROOT/}"

# 2) デバイス確保
if [ "$TARGET" = "device" ]; then
  SERIAL="$(pick_device "${ANDROID_SERIAL:-}")" || SERIAL=""
  if [ -z "$SERIAL" ]; then
    log_error "実機が接続されていません（USB デバッグ許可を確認）"
    exit 1
  fi
else
  # HEADFUL でエミュレータ
  export HEADFUL=1
  SERIAL="$(pick_device "")" || SERIAL=""
  if [ -z "$SERIAL" ]; then
    SERIAL="$("$SCRIPTS_DIR/start_emulator.sh" | tail -1)" || { log_error "エミュレータ確保失敗"; exit 1; }
  fi
fi
stabilize_device "$SERIAL"
log_info "対象デバイス: $TARGET ($SERIAL)"

# 3) クリーンアンインストール（前バージョン残骸の除去）
log_info "クリーンアンインストール"
"$SCRIPTS_DIR/uninstall.sh" "$SERIAL" >/dev/null 2>&1 || true

# 4) release APK インストール
log_info "release APK インストール"
"$SCRIPTS_DIR/install.sh" "$RELEASE_APK" "$SERIAL" >/dev/null || { log_error "install 失敗"; exit 1; }

# 5) logcat クリア + 起動 smoke
"$ADB_BIN" -s "$SERIAL" logcat -c 2>/dev/null || true
"$SCRIPTS_DIR/run.sh" "$SERIAL" || { log_error "アプリ起動失敗"; exit 1; }

RC=0
RAN_FLOWS=()

# 6) smoke + 全 maestro flow
SMOKE="$MAESTRO_DIR/smoke.yaml"
if [ -f "$SMOKE" ]; then
  log_info "release smoke: maestro/smoke.yaml"
  run_with_timeout "$TIMEOUT_SEC" "$SCRIPTS_DIR/test_maestro.sh" "$SMOKE" "_release_smoke" || RC=1
  RAN_FLOWS+=("smoke")
fi

# release.yaml::release_smoke_flows の指定があれば優先、無ければ全 flow（_integration / _polish を除外）
LIST="$(conf_list "$CONF" release_smoke_flows)"
if [ -z "$LIST" ]; then
  for f in "$MAESTRO_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    bn="$(basename "$f")"
    [ "$bn" = "smoke.yaml" ] && continue
    LIST="$LIST"$'\n'"$bn"
  done
fi

while IFS= read -r fl; do
  [ -z "$fl" ] && continue
  full="$MAESTRO_DIR/$fl"
  [ -f "$full" ] || { log_warn "flow が存在しません: $fl"; continue; }
  name="$(basename "$fl" .yaml)"
  log_info "release smoke: $name"
  if ! run_with_timeout "$TIMEOUT_SEC" "$SCRIPTS_DIR/test_maestro.sh" "$full" "_release_$name"; then
    log_error "FAIL: $name"
    RC=1
  fi
  RAN_FLOWS+=("$name")
done <<< "$LIST"

# 7) logcat ダンプ + クラッシュスキャン
LOG_OUT="$EVIDENCE_OUT/logcat/logcat_$(date +%Y%m%d_%H%M%S).txt"
dump_logcat "$SERIAL" "$LOG_OUT" >/dev/null
if ! scan_logcat_crash "$LOG_OUT"; then
  log_error "logcat にクラッシュ痕跡（${LOG_OUT#$REPO_ROOT/}）"
  RC=1
fi

# 8) 最終スクショ
"$SCRIPTS_DIR/screenshot.sh" "_release" "final_$(date +%H%M%S)" "$SERIAL" >/dev/null || log_warn "スクショ取得失敗"

# 9) 結果記録（attestation 用）
OUT="$STATE_DIR/release_smoke_last.json"
mkdir -p "$STATE_DIR"
{
  printf '{\n'
  printf '  "executed_at": "%s",\n' "$(date -Iseconds 2>/dev/null || date)"
  printf '  "target": "%s",\n' "$TARGET"
  printf '  "device_serial": "%s",\n' "$SERIAL"
  printf '  "apk_path": "%s",\n' "${RELEASE_APK#$REPO_ROOT/}"
  printf '  "logcat": "%s",\n' "${LOG_OUT#$REPO_ROOT/}"
  printf '  "evidence_dir": "%s",\n' "${EVIDENCE_OUT#$REPO_ROOT/}"
  printf '  "flows": ['
  flow_first=1
  for f in "${RAN_FLOWS[@]}"; do
    [ "$flow_first" = "0" ] && printf ', '
    printf '"%s"' "$f"
    flow_first=0
  done
  printf '],\n'
  printf '  "result": "%s"\n' "$([ "$RC" = "0" ] && echo pass || echo fail)"
  printf '}\n'
} > "$OUT"
log_info "結果記録: ${OUT#$REPO_ROOT/}"

if [ "$RC" -ne 0 ]; then
  log_error "run_release_smoke FAIL"
  echo "  → fail を 修正_リリース_<項目>.md として生成し fix-loop で対応してください（RG3）。"
  exit "$RC"
fi
log_info "run_release_smoke PASS"
