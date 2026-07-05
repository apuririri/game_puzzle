#!/usr/bin/env bash
# Resume 時の ground-truth 再検証（案1 / 改善案レポート#1）。
# current.json の loop_phase / last_step に応じた最小限の再検証を実行し、結果を
# state/resume_verifications/<ts>.json に記録する。
# 使い方:
#   verify_resume_point.sh           # 検証して exit 0/1
# 失敗時は AI が直前コミットまで巻き戻すか blocked=true を立てる判断材料となる。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq が必要です。" >&2; exit 2; }

CUR="$STATE_DIR/current.json"
[ -f "$CUR" ] || { echo "[SKIP] current.json 不在 (初期状態)."; exit 0; }

MODE="$(jq -r '.mode // ""' "$CUR")"
TARGET="$(jq -r '.target // ""' "$CUR")"
PHASE="$(jq -r '.loop_phase // ""' "$CUR")"
LAST_STEP="$(jq -r '.last_step // ""' "$CUR")"
BLOCKED="$(jq -r '.blocked // false' "$CUR")"

if [ -z "$MODE" ]; then
  echo "[OK] mode 空（完了/未着手）。再検証 skip。"
  exit 0
fi
if [ "$BLOCKED" = "true" ]; then
  echo "[OK] blocked=true（解消待ち）。再検証 skip。"
  exit 0
fi

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$STATE_DIR/resume_verifications"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/${TS}.json"

CHECKS=()
PASS=()
FAIL=()
run_check() {
  local name="$1"; shift
  CHECKS+=("$name")
  if "$@" >/dev/null 2>&1; then PASS+=("$name"); echo "  [OK]   $name"
  else                          FAIL+=("$name"); echo "  [FAIL] $name"
  fi
}

echo "== resume 再検証: mode=$MODE target=$TARGET phase=$PHASE last_step=\"$LAST_STEP\" =="

# (a) state 整合性は常に検証
run_check "state_consistency" "$SCRIPTS_DIR/check_state_consistency.sh"

# (b) last_step 種別ごとの追加検証
case "$LAST_STEP" in
  *test*|*maestro*|*device*|*verify*)
    # 直前テストの再実行は重いので、attestation 内 evidence パス存在のみ確認
    if [ -n "$TARGET" ] && [ -f "$STATE_DIR/attestations/${TARGET}.json" ]; then
      AT="$STATE_DIR/attestations/${TARGET}.json"
      run_check "evidence_path_exists" bash -c "ev=\$(jq -r '.evidence.screenshots // \"\"' '$AT'); [ -n \"\$ev\" ] && [ -d '$REPO_ROOT/'\$ev ]"
    fi
    ;;
  *commit*|*close*|*attestation*)
    if [ -n "$TARGET" ] && [ -f "$STATE_DIR/attestations/${TARGET}.json" ]; then
      AT="$STATE_DIR/attestations/${TARGET}.json"
      run_check "attestation_gates_ok" bash -c "jq -e '[.gates[]?] | length>0 and all(. == \"ok\")' '$AT' >/dev/null"
    fi
    ;;
  *) ;;
esac

# (c) 進捗.md ↔ state の同期
run_check "progress_md_sync" "$SCRIPTS_DIR/check_progress_md_sync.sh"

# 結果 JSON 出力
RESULT="passed"
[ "${#FAIL[@]}" -gt 0 ] && RESULT="failed"

arr_to_json() {
  if [ "$#" -eq 0 ]; then echo '[]'; return; fi
  jq -nc --args '$ARGS.positional' "$@"
}
{
  jq -n \
    --arg ts "$(date -Iseconds 2>/dev/null || date)" \
    --arg mode "$MODE" --arg target "$TARGET" --arg phase "$PHASE" --arg last_step "$LAST_STEP" \
    --arg result "$RESULT" \
    --argjson checks "$(arr_to_json "${CHECKS[@]:-}")" \
    --argjson passed "$(arr_to_json "${PASS[@]:-}")" \
    --argjson failed "$(arr_to_json "${FAIL[@]:-}")" \
    '{
      schema: "resume_verification.v1",
      ts: $ts, mode: $mode, target: $target, phase: $phase, last_step: $last_step,
      result: $result, checks: $checks, passed: $passed, failed: $failed
    }'
} > "$OUT"

echo
echo "  記録: $OUT"
if [ "$RESULT" = "passed" ]; then
  echo "[OK] resume 再検証 PASS（${#PASS[@]}/${#CHECKS[@]}）。"
  exit 0
fi
echo "[FAIL] resume 再検証 FAIL（${#FAIL[@]} 件失敗）。"
echo "  対処: 直前の安全なチェックポイント（最新コミット）まで巻き戻して再開、または"
echo "        set_current.sh ... true \"<理由>\" で blocked=true を立て、人手判断待ちにしてください。"
exit 1
