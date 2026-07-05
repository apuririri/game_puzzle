#!/usr/bin/env bash
# S10 IV3 全機能統合実機検証（FR-5.17.4）。
# HEADFUL モードでデバイス確保 → クリーン install → 全機能 Maestro flow + 機能横断シナリオ実行
# → 全画面スクショ + logcat ダンプ + クラッシュスキャンを行う。
#
# 使い方: run_integration_check.sh
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

CONF="$AUTODEV_DIR/config/integration.yaml"
EVIDENCE_OUT="$REPO_ROOT/$(conf_get "$CONF" evidence_dir "autodev/evidence/_integration")"
REQUIRE_HEADFUL="$(conf_get "$CONF" require_headful true)"
TIMEOUT_SEC="$(conf_get "$CONF" timeout_sec 1800)"

mkdir -p "$EVIDENCE_OUT/screenshots" "$EVIDENCE_OUT/logcat"

# 1) HEADFUL でエミュレータ確保
if [ "$REQUIRE_HEADFUL" = "true" ]; then
  export HEADFUL=1
  log_info "HEADFUL モードでエミュレータを起動します（require_headful=true）"
fi
SERIAL="$(pick_device "")" || SERIAL=""
if [ -z "$SERIAL" ]; then
  SERIAL="$("$SCRIPTS_DIR/start_emulator.sh" | tail -1)" || { log_error "デバイス確保失敗"; exit 1; }
fi
stabilize_device "$SERIAL"

# 2) クリーンアンインストール → 最新 debug ビルド → install → 起動
log_info "クリーンアンインストール"
"$SCRIPTS_DIR/uninstall.sh" "$SERIAL" >/dev/null 2>&1 || true
log_info "debug ビルド"
"$SCRIPTS_DIR/build.sh" debug >/dev/null || { log_error "ビルド失敗"; exit 1; }
"$SCRIPTS_DIR/install.sh" "$(apk_path debug)" "$SERIAL" >/dev/null || exit 1

# 3) logcat クリア
"$ADB_BIN" -s "$SERIAL" logcat -c 2>/dev/null || true

# 4) 全機能 Maestro flow + 機能横断シナリオ実行
RC=0
RAN_FLOWS=()

# (a) 機能ごとの flow（maestro/*.yaml で _integration/ smoke 以外）
FEATURE_FLOWS="$(ls "$MAESTRO_DIR"/*.yaml 2>/dev/null | grep -v '/smoke.yaml$' || true)"
# smoke を先頭に
ORDERED_FLOWS=""
[ -f "$MAESTRO_DIR/smoke.yaml" ] && ORDERED_FLOWS="$MAESTRO_DIR/smoke.yaml"
for fl in $FEATURE_FLOWS; do ORDERED_FLOWS="$ORDERED_FLOWS"$'\n'"$fl"; done

# (b) 機能横断シナリオ（maestro/_integration/*.yaml）。設定の cross_feature_flows で順序指定があれば優先。
CROSS=""
CONF_CROSS="$(conf_list "$CONF" cross_feature_flows)"
if [ -n "$CONF_CROSS" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    CROSS="$CROSS"$'\n'"$MAESTRO_DIR/_integration/$f"
  done <<< "$CONF_CROSS"
else
  if [ -d "$MAESTRO_DIR/_integration" ]; then
    for f in "$MAESTRO_DIR/_integration"/*.yaml; do
      [ -f "$f" ] || continue
      CROSS="$CROSS"$'\n'"$f"
    done
  fi
fi

ALL_FLOWS="$ORDERED_FLOWS$CROSS"

while IFS= read -r flow; do
  [ -z "$flow" ] && continue
  [ -f "$flow" ] || { log_warn "flow が存在しません: $flow"; continue; }
  name="$(basename "$flow" .yaml)"
  log_info "実機統合シナリオ: $name"
  if ! run_with_timeout "$TIMEOUT_SEC" "$SCRIPTS_DIR/test_maestro.sh" "$flow" "_integration_$name"; then
    log_error "FAIL: $name"
    RC=1
  fi
  RAN_FLOWS+=("$name")
done <<< "$ALL_FLOWS"

# 5) 最終スクショ
"$SCRIPTS_DIR/screenshot.sh" "_integration" "final_$(date +%H%M%S)" "$SERIAL" >/dev/null || log_warn "スクショ取得失敗"

# 6) logcat ダンプ + クラッシュスキャン
LOG_OUT="$EVIDENCE_OUT/logcat/logcat_$(date +%Y%m%d_%H%M%S).txt"
dump_logcat "$SERIAL" "$LOG_OUT" >/dev/null
if ! scan_logcat_crash "$LOG_OUT"; then
  log_error "logcat にクラッシュ痕跡（${LOG_OUT#$REPO_ROOT/}）"
  RC=1
fi

# 7) 結果サマリ
echo
echo "===== 統合実機検証 サマリ ====="
echo "実行 flow 数: ${#RAN_FLOWS[@]}"
for f in "${RAN_FLOWS[@]}"; do echo "  - $f"; done
echo "証跡: ${EVIDENCE_OUT#$REPO_ROOT/}"
echo "logcat: ${LOG_OUT#$REPO_ROOT/}"

if [ "$RC" -ne 0 ]; then
  log_error "統合実機検証 FAIL"
  echo "  → 検出した不具合・改善要望を 修正_統合_<項目>.md として生成し fix-loop で対応してください。"
  exit "$RC"
fi
log_info "統合実機検証 PASS"
