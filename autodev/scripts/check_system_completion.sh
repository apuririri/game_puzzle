#!/usr/bin/env bash
# システムループ完了ゲート（CLAUDE_MAIN.md 規約13）。
# autodev-system-loop の S15（完了報告 / mode=""）を宣言する前の絶対ゲート。
# set_current.sh が mode を空にする操作および PostToolUse hook が「✅ システム完了」を
# 進捗.md に書き込むタイミングで呼ばれる。
#
# 使い方:
#   check_system_completion.sh           # 全項目検査。1件でも fail なら exit 1。
#   check_system_completion.sh --warn    # exit 0 で続行（軽量実行用）。
#
# 検査項目（すべて PASS が必須）:
#   [1] system.json が存在し features 配列が空でない
#   [2] system.json::features[] すべてが status=done
#   [3] features[].id ごとに attestations/<id>.json が存在
#   [4] system.json::persona_test_plan.schedule[] が1件以上あり、全 status=completed
#   [5] persona_test_plan.schedule[].run_id ごとに persona_tests/<番号>.json が存在
#   [6] 全機能で UI 層タスクが少なくとも1件存在（要件定義書からの UI 必須機能漏れ防止）
#   [7] 顧客向けドキュメント整備済み（README.md, docs/操作手順書.md, docs/インストール手順.md）
#   [8] S12 全体スモークの最新証跡が存在（autodev/evidence/_smoke/ または system attestation）
#   [9] 言い訳語ゲート check_no_skip_excuses.sh が PASS
#  [10] S10 全体結合確認・改善 attestation（attestations/integration.json）あり + check_no_mocks PASS
#  [11] S11 UIデザイン改善 attestation（attestations/ui_polish.json）あり + check_ui_polish_evidence PASS
#  [12] S14 デプロイ・リリース最終確認 attestation（attestations/release.json）あり + decision="releasable"
#  [13] S6.5 要件↔設計カバレッジ attestation（attestations/coverage.json）あり + passed=true
#       （coverage_check.enabled=false で system.json::s6_5_result が null のときはスキップ / FR-5.21.1）
#  [14] 全機能 attestation の traceability_passed=true（FR-5.21.2.9）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
[ "${1:-}" = "--warn" ] && MODE="warn"

command -v jq >/dev/null 2>&1 || { echo "[FAIL] jq が必要です"; exit 2; }

SYS="$STATE_DIR/loops/system.json"
FAIL=0
fail() { echo "[FAIL] $*"; FAIL=1; }
ok()   { echo "[OK] $*"; }

# [1] system.json と features の存在
if [ ! -f "$SYS" ]; then
  fail "system.json が未生成（S1 未到達）。"
else
  FEAT_N="$(jq -r '.features | length' "$SYS" 2>/dev/null || echo 0)"
  if [ "${FEAT_N:-0}" = "0" ] || [ -z "$FEAT_N" ]; then
    fail "system.json::features が空（S2/S5 未完了）。"
  else
    ok "system.json::features = $FEAT_N 機能"
  fi
fi

# [2] features すべてが done
if [ -f "$SYS" ]; then
  NOT_DONE="$(jq -r '[.features[]? | select(.status != "done")] | length' "$SYS")"
  if [ "${NOT_DONE:-0}" -gt 0 ]; then
    fail "未完了の機能が $NOT_DONE 件あります（status != done）。S12 完了宣言不可。"
    jq -r '.features[]? | select(.status != "done") | "  - \(.id) [\(.name)] status=\(.status)"' "$SYS"
  else
    ok "全機能 status=done"
  fi
fi

# [3] features[].id ごとに attestation 存在
if [ -f "$SYS" ]; then
  MISSING_ATT=0
  while IFS= read -r fid; do
    [ -z "$fid" ] && continue
    if [ ! -f "$STATE_DIR/attestations/${fid}.json" ]; then
      fail "feature=$fid: attestations/${fid}.json が不在"
      MISSING_ATT=1
    fi
  done < <(jq -r '.features[]?.id' "$SYS")
  [ "$MISSING_ATT" = "0" ] && ok "全機能 attestation 存在"
fi

# [4] persona_test_plan.schedule 完了
if [ -f "$SYS" ]; then
  PT_N="$(jq -r '.persona_test_plan.schedule | length' "$SYS" 2>/dev/null || echo 0)"
  if [ "${PT_N:-0}" = "0" ] || [ -z "$PT_N" ]; then
    fail "persona_test_plan.schedule が空（S7 未完了 / FR-5.9.2 違反）。"
  else
    PT_NOT_DONE="$(jq -r '[.persona_test_plan.schedule[] | select(.status != "completed")] | length' "$SYS")"
    if [ "${PT_NOT_DONE:-0}" -gt 0 ]; then
      fail "未完了のペルソナテストが $PT_NOT_DONE 件あります（規約15）。S12 完了宣言不可。"
      jq -r '.persona_test_plan.schedule[] | select(.status != "completed") | "  - run_id=\(.run_id) trigger=\(.trigger // "-") status=\(.status)"' "$SYS"
    else
      ok "全 persona_test schedule status=completed ($PT_N 回)"
    fi
  fi
fi

# [5] persona_test ファイル存在
# ファイル名は 2 形式（ゼロ詰めあり/なし）を許容する。新採番ルール（B.7）では
# 非ゼロ詰めの `<番号>.json` が正規だが、既存運用で 2 桁ゼロ詰めの実施記録も
# 存在するため、両形式を探索して PASS と判定する。
if [ -f "$SYS" ]; then
  PT_MISSING=0
  while IFS= read -r rid; do
    [ -z "$rid" ] && continue
    FN_PAD="$(printf '%02d' "$rid" 2>/dev/null || echo "$rid")"
    if [ -f "$STATE_DIR/persona_tests/${rid}.json" ] || [ -f "$STATE_DIR/persona_tests/${FN_PAD}.json" ]; then
      :
    else
      fail "persona_test run_id=$rid: ${rid}.json / ${FN_PAD}.json 不在（実施記録なし）。"
      PT_MISSING=1
    fi
  done < <(jq -r '.persona_test_plan.schedule[]?.run_id' "$SYS")
  [ "$PT_MISSING" = "0" ] && ok "全 persona_test 実施記録 (state/persona_tests/) 存在"
fi

# [6] 各機能で UI 層タスクが存在（規約15: UI を後続作業として除外させない）
# tasks/<feature>.json::tasks[] に layer="ui" もしくは design_doc_ref.section/file に ui/screen
# もしくは file が ui/screen/ 配下のタスクが少なくとも1件あること。
if [ -f "$SYS" ]; then
  UI_MISS=0
  while IFS= read -r fid; do
    [ -z "$fid" ] && continue
    TF="$STATE_DIR/tasks/${fid}.json"
    if [ ! -f "$TF" ]; then
      fail "feature=$fid: tasks/${fid}.json が不在（F3 タスク分割未完了の疑い）。"
      UI_MISS=1
      continue
    fi
    # UI 層タスクの判定: layer="ui" / files に ui/screen を含む / design_doc_ref.section に画面・Compose 言及
    HAS_UI="$(jq -r '
      [.tasks[]? | select(
        (.layer // "") == "ui" or
        ((.files // []) | any(test("ui/(screen|component|navigation)/"))) or
        ((.design_doc_ref.section // "") | test("(画面|Composable|Screen|UI)"; "ix")) or
        ((.design_doc_ref.file // "") | test("ui/(screen|component|navigation)/"))
      )] | length
    ' "$TF" 2>/dev/null || echo 0)"
    if [ "${HAS_UI:-0}" = "0" ]; then
      # 機能のメタに ui_required=false が明示されていれば除外（DB 基盤など）。
      # jq の `// "true"` は false 値も置換してしまうため、boolean を直接判定する。
      UI_NOT_REQ="$(jq -r --arg id "$fid" '.features[]? | select(.id==$id) | (.ui_required == false)' "$SYS")"
      if [ "$UI_NOT_REQ" = "true" ]; then
        ok "feature=$fid: ui_required=false（基盤機能のため UI タスク不要）"
      else
        fail "feature=$fid: UI 層タスクが0件（規約15）。ui/screen 系のタスクを必ず含めること。"
        UI_MISS=1
      fi
    fi
  done < <(jq -r '.features[]?.id' "$SYS")
  [ "$UI_MISS" = "0" ] && ok "全機能で UI 層タスク存在"
fi

# [7] 顧客向けドキュメント
DOC_MISS=0
for d in \
  "$REPO_ROOT/README.md" \
  "$REPO_ROOT/docs/操作手順書.md" \
  "$REPO_ROOT/docs/インストール手順.md"; do
  if [ ! -f "$d" ]; then
    fail "顧客向けドキュメント不在: ${d#$REPO_ROOT/}（S13 未完了）。"
    DOC_MISS=1
  fi
done
[ "$DOC_MISS" = "0" ] && ok "顧客向けドキュメント 3 種すべて存在"

# [8] S12 全体スモーク証跡（旧 S10）
# evidence/_smoke/ または attestations/system.json::smoke_evidence、もしくは
# 直近の evidence/maestro/ に smoke 関連ファイルがあること。
SMOKE_OK=0
if [ -d "$EVIDENCE_DIR/_smoke" ] && [ "$(find "$EVIDENCE_DIR/_smoke" -type f 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
  SMOKE_OK=1
fi
SYS_ATT="$STATE_DIR/attestations/system.json"
if [ "$SMOKE_OK" = "0" ] && [ -f "$SYS_ATT" ]; then
  if jq -e '.smoke_evidence // empty' "$SYS_ATT" >/dev/null 2>&1; then
    SMOKE_OK=1
  fi
fi
if [ "$SMOKE_OK" = "1" ]; then
  ok "S12 全体スモーク証跡あり"
else
  fail "S12 全体スモーク証跡なし（evidence/_smoke/ も attestations/system.json::smoke_evidence も不在）。"
fi

# [9] 言い訳語ゲート
if [ -x "$SCRIPTS_DIR/check_no_skip_excuses.sh" ]; then
  if "$SCRIPTS_DIR/check_no_skip_excuses.sh"; then
    ok "言い訳語ゲート PASS"
  else
    fail "言い訳語ゲート NG（規約14 違反）。"
  fi
fi

# [10] S10 全体結合確認・改善 attestation + check_no_mocks PASS
INT_ATT="$STATE_DIR/attestations/integration.json"
if [ ! -f "$INT_ATT" ]; then
  fail "S10 全体結合確認・改善 attestation 不在: ${INT_ATT#$REPO_ROOT/}（FR-5.17 違反）。"
else
  ok "S10 統合確認 attestation 存在"
  if [ -x "$SCRIPTS_DIR/check_no_mocks.sh" ]; then
    if "$SCRIPTS_DIR/check_no_mocks.sh" >/dev/null 2>&1; then
      ok "check_no_mocks PASS（プロダクション側にモック残存なし）"
    else
      fail "check_no_mocks NG（モック/スタブ/TODO 残存あり / FR-5.17.2 違反）。"
    fi
  fi
fi

# [11] S11 UIデザイン改善 attestation + check_ui_polish_evidence PASS
UI_ATT="$STATE_DIR/attestations/ui_polish.json"
if [ ! -f "$UI_ATT" ]; then
  fail "S11 UIデザイン改善 attestation 不在: ${UI_ATT#$REPO_ROOT/}（FR-5.18 違反）。"
else
  ok "S11 UI 改善 attestation 存在"
  if [ -x "$SCRIPTS_DIR/check_ui_polish_evidence.sh" ]; then
    if "$SCRIPTS_DIR/check_ui_polish_evidence.sh" >/dev/null 2>&1; then
      ok "check_ui_polish_evidence PASS（全画面 before/after 揃い）"
    else
      fail "check_ui_polish_evidence NG（全画面 before/after が揃っていません / FR-5.18.9 違反）。"
    fi
  fi
fi

# [12] S14 デプロイ・リリース最終確認 attestation + decision="releasable"
REL_ATT="$STATE_DIR/attestations/release.json"
if [ ! -f "$REL_ATT" ]; then
  fail "S14 リリース最終確認 attestation 不在: ${REL_ATT#$REPO_ROOT/}（FR-5.19 違反）。"
else
  DECISION="$(jq -r '.decision // "(decision フィールド未設定)"' "$REL_ATT" 2>/dev/null)"
  if [ "$DECISION" = "releasable" ]; then
    ok "S14 リリース attestation: decision=releasable"
  else
    fail "S14 リリース attestation: decision=\"$DECISION\"（\"releasable\" 必須 / FR-5.19.5 違反）。"
  fi
fi

# [13] S6.5 要件↔設計カバレッジ attestation（FR-5.21.1）
# loop.yaml::coverage_check.enabled=false の場合は system.json::s6_5_result が null となる想定で、
# その場合は本検査をスキップ（規約15 ホワイトリスト準拠）。
COV_ATT="$STATE_DIR/attestations/coverage.json"
if [ -f "$SYS" ]; then
  S6_5_PRESENT="$(jq -r '.s6_5_result // empty | type' "$SYS" 2>/dev/null)"
  if [ "$S6_5_PRESENT" = "object" ]; then
    S6_5_PASSED="$(jq -r '.s6_5_result.passed // false' "$SYS" 2>/dev/null)"
    if [ "$S6_5_PASSED" != "true" ]; then
      fail "S6.5 要件↔設計カバレッジ未 PASS（system.json::s6_5_result.passed != true / FR-5.21.1 違反）。"
    else
      if [ ! -f "$COV_ATT" ]; then
        fail "S6.5 coverage attestation 不在: ${COV_ATT#$REPO_ROOT/}（FR-5.21.1.6 違反）。"
      else
        COV_OK="$(jq -r '.passed // false' "$COV_ATT" 2>/dev/null)"
        if [ "$COV_OK" = "true" ]; then
          ok "S6.5 coverage attestation PASS"
        else
          fail "S6.5 coverage attestation::passed != true（ギャップ残存 / FR-5.21.1 違反）。"
        fi
      fi
    fi
  else
    ok "S6.5 coverage check はスキップ設定（coverage_check.enabled=false 想定）"
  fi
fi

# [14] 全機能 attestation の traceability_passed=true（FR-5.21.2.9）
# feature_loop.traceability_enabled=false で attestation の traceability_ref が null / traceability_passed=true
# (SKIP も PASS 扱い) の場合は許容（規約15 ホワイトリスト準拠）。
if [ -f "$SYS" ]; then
  TRACE_MISS=0
  while IFS= read -r fid; do
    [ -z "$fid" ] && continue
    AF="$STATE_DIR/attestations/${fid}.json"
    [ -f "$AF" ] || continue   # attestation 不在は [3] で既に検出済み
    TP="$(jq -r '.traceability_passed // empty' "$AF" 2>/dev/null)"
    if [ -z "$TP" ]; then
      fail "feature=$fid: attestation に traceability_passed フィールド未設定（FR-5.21.2.9 違反）。"
      TRACE_MISS=1
    elif [ "$TP" != "true" ]; then
      fail "feature=$fid: traceability_passed=$TP（F5.5 トレーサビリティ未 PASS / FR-5.21.2 違反）。"
      TRACE_MISS=1
    fi
  done < <(jq -r '.features[]?.id' "$SYS")
  [ "$TRACE_MISS" = "0" ] && ok "全機能 attestation::traceability_passed=true"
fi

echo
if [ "$FAIL" = "1" ]; then
  echo "[FAIL] システム完了ゲート NG。S15 完了宣言（mode=\"\" / ✅ システム完了）を行ってはなりません。"
  echo "       未満項目を解消するか、人手介入待ちで停止してください（current.json::blocked=true）。"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] システム完了ゲート PASS。S15 完了宣言を行ってよい状態です。"
exit 0
