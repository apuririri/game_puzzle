#!/usr/bin/env bash
# ペルソナ駆動テストの実行スキャフォールド（FR-5.9 / 修正方針 §3-9 / Android 版）。
# 使い方:
#   run_persona_tests.sh <実施番号> [--scope system|feature:<名>|fix:<名>]
#
#   - デバイス確保（無ければエミュレータ起動）+ 最新ビルドをインストール
#   - スコープに応じた Maestro flow を実行
#       system           → maestro/persona/persona_<番号>_*.yaml （従来挙動）
#       feature:<機能名> → maestro/persona/persona_<番号>_feature_<機能名>_*.yaml
#       fix:<修正名>     → maestro/persona/persona_<番号>_fix_<修正名>_*.yaml
#   - 証跡（スクショ・logcat）を autodev/evidence/persona_tests/<番号>/[<scope>/] に集約
# ※ ペルソナのロールプレイ・改善要望生成は AI（autodev-persona-test skill）が行う。
#    本スクリプトはデバイス確保・ビルド・flow 実行・証跡集約の機械部分のみ担う。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

usage() {
  sed -n '2,14p' "$0"
}

NUM=""
SCOPE="system"
while [ $# -gt 0 ]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --scope=*) SCOPE="${1#--scope=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [ -z "$NUM" ]; then NUM="$1"; shift
      else log_error "未知の引数: $1"; usage; exit 2
      fi ;;
  esac
done
NUM="${NUM:-1}"

# scope の検証と flow パターン・証跡サブパスを決定
case "$SCOPE" in
  system)
    FLOW_PATTERN="$MAESTRO_DIR/persona/persona_${NUM}_*.yaml"
    EVIDENCE_SUB=""
    ;;
  feature:*)
    NAME="${SCOPE#feature:}"
    if [ -z "$NAME" ]; then log_error "feature: の後ろが空です"; exit 2; fi
    FLOW_PATTERN="$MAESTRO_DIR/persona/persona_${NUM}_feature_${NAME}_*.yaml"
    EVIDENCE_SUB="feature_${NAME}"
    ;;
  fix:*)
    NAME="${SCOPE#fix:}"
    if [ -z "$NAME" ]; then log_error "fix: の後ろが空です"; exit 2; fi
    FLOW_PATTERN="$MAESTRO_DIR/persona/persona_${NUM}_fix_${NAME}_*.yaml"
    EVIDENCE_SUB="fix_${NAME}"
    ;;
  *)
    log_error "scope の指定が不正です: $SCOPE"
    log_error "system | feature:<名> | fix:<名> のいずれかを指定してください。"
    exit 2
    ;;
esac

OUT="$EVIDENCE_DIR/persona_tests/$NUM"
[ -n "$EVIDENCE_SUB" ] && OUT="$OUT/$EVIDENCE_SUB"
mkdir -p "$OUT"

SERIAL="$(pick_device "")" || SERIAL=""
[ -z "$SERIAL" ] && SERIAL="$("$SCRIPTS_DIR/start_emulator.sh" | tail -1)"
[ -z "$SERIAL" ] && { log_error "デバイス確保に失敗"; exit 1; }
stabilize_device "$SERIAL"

"$SCRIPTS_DIR/build.sh" debug >/dev/null && "$SCRIPTS_DIR/install.sh" "$(apk_path debug)" "$SERIAL" >/dev/null || exit 1

FLOWS="$(ls $FLOW_PATTERN 2>/dev/null || true)"
if [ -z "$FLOWS" ]; then
  log_warn "flow が見つかりません: $FLOW_PATTERN"
  log_warn "autodev-persona-test skill に従い、スコープ($SCOPE)対応のシナリオ flow を生成してから再実行してください。"
  exit 0
fi

log_info "ペルソナテスト開始 scope=$SCOPE num=$NUM serial=$SERIAL"
RC=0
for fl in $FLOWS; do
  log_info "ペルソナ flow 実行: ${fl#$REPO_ROOT/}"
  "$ADB_BIN" -s "$SERIAL" logcat -c 2>/dev/null || true
  "$SCRIPTS_DIR/run_maestro.sh" test --debug-output "$OUT/$(basename "$fl" .yaml)" "$fl" || RC=1
  "$ADB_BIN" -s "$SERIAL" exec-out screencap -p > "$OUT/$(basename "$fl" .yaml)_final.png" 2>/dev/null || true
  dump_logcat "$SERIAL" "$OUT/$(basename "$fl" .yaml)_logcat.txt" >/dev/null
done

log_info "ペルソナテスト証跡: ${OUT#$REPO_ROOT/}"
exit "$RC"
