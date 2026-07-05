#!/usr/bin/env bash
# 「言い訳語」検出ゲート（CLAUDE_MAIN.md 規約14）。
# AIエージェントがフェーズ・ステップを自己判断で省略・後回し・打ち切る際に
# 進捗.md / state / attestation / current.json に書きがちな禁止語句を機械検出する。
#
# 使い方:
#   check_no_skip_excuses.sh             # 進捗.md と state 全体を走査。1件でも検出すれば exit 1。
#   check_no_skip_excuses.sh --target <名>  # 特定 attestation/loops/tasks のみ走査。
#   check_no_skip_excuses.sh --strict    # exit 1（既定。互換用引数）。
#   check_no_skip_excuses.sh --warn      # 検出しても exit 0（hook 軽量実行用）。
#
# 禁止語の判定方針:
#   - 「時間制約」「時間の都合」「時間がない」「コンテキスト圧迫」を理由にしたスキップ宣言を検出。
#   - 「後続作業」「次セッションで」「将来対応」「将来実装」「後で実装」「省略しました」
#     「スキップしました」「割愛しました」「打ち切り」「TODO として残す」を検出。
#   - 純粋な日本語の「TODO:」コメントや、ペルソナ定義の「将来は…」のような一般的言及は
#     対象外（フェーズ・ステップの省略宣言と紐付かない単独単語）。
#     → これを実現するため、検出は禁止フレーズ単位で行う（単語の "TODO" 単独はヒットさせない）。
#
# ホワイトリスト（規約15 / FR-5.9.8 / FR-5.9.9）:
#   - `loop.yaml::feature_loop.persona_test_enabled=false`（F6.5 を明示 OFF）。
#   - `loop.yaml::fix_loop.persona_test_enabled=false`（R6.5 を明示 OFF）。
#   - R6.5 のスキップ条件①②③（severity 足切り / source_scope による無限ループ防止 / 設定 OFF）。
#     これらは「設計された動作」であり「言い訳による省略」ではない。
#   - state/persona_tests/<番号>.json の `r6_5_skip_reason` には**禁止語句にひっかからない条件式**
#     （例: "fix_loop.persona_test_enabled=false" / "severity=low < threshold=medium" /
#     "source_scope=feature (loop-prevention)"）で書くこと。「省略しました」「スキップしました」
#     等の言い訳語をそのまま書かない（書いた場合は本ゲートで fail し、レビュー対象になる）。
#
# 検出対象:
#   - autodev/開発進捗状況.md
#   - autodev/state/loops/*.json
#   - autodev/state/attestations/*.json
#   - autodev/state/current.json (blocked_reason 除外: blocked=true なら一時停止理由として許容)
#   - autodev/state/persona_tests/*.json
#   - autodev/inputs/修正対応/修正_*.md（コミット時の判定対象外。手動入力用）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) MODE="strict"; shift ;;
    --warn)   MODE="warn";   shift ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    *) echo "[FAIL] 不明な引数: $1"; exit 2 ;;
  esac
done

# 禁止フレーズ（grep -E の ERE）
# - 単独単語ではなく、スキップ宣言を含むフレーズで検出する。
FORBIDDEN_PATTERNS=(
  '時間(制約|の都合|がない|不足).*((省略|スキップ|割愛|打ち切|後回し|後続|未実施|未着手)|実施(しません|せず|しない))'
  '(コンテキスト|トークン).*(圧迫|削減|節約).*((省略|スキップ|割愛|後回し|未実施)|実施(しません|せず|しない))'
  '(後続作業|次セッション|将来対応|将来実装|後で実装|今回はスキップ|今回は省略|今回は割愛|今回は実施しません)'
  '(省略しました|スキップしました|割愛しました|打ち切りました|未実施のまま|未着手のまま).*(クローズ|完了|終了|報告)'
  '(クローズ|完了|終了|報告).*(省略|スキップ|割愛|打ち切|後回し).*(しました|します|する)'
  'TODO[: ].*(後続|将来|次セッション|時間)'
  '(ペルソナテスト|persona[ _-]?test).*(省略|スキップ|割愛|未実施|実施しません|実施せず|実施しない|不要)'
  '(UI|ui/screen|画面).*((実装|開発).*(省略|スキップ|割愛|後続作業|後回し|未着手|後で実装))'
  '(スコープ.*(外|縮小|調整|削減)).*(完了|クローズ|終了|報告)'
  '(統合確認|integration[ _-]?verify|S10).*(省略|スキップ|割愛|未実施|実施しません|実施せず|不要)'
  '(UI改善|UIデザイン改善|ui[ _-]?polish|S11).*(省略|スキップ|割愛|未実施|実施しません|実施せず|不要)'
  '(リリース.*(最終)?確認|release[ _-]?gate|S14).*(省略|スキップ|割愛|未実施|実施しません|実施せず|不要)'
  '(モック|mock|スタブ|stub|TODO).*(残.*(まま|許容|許可).*(クローズ|完了|報告)|そのまま.*(クローズ|完了))'
)

scan_file() {
  # $1: ファイルパス（絶対パスでも相対パスでも可）
  local f="$1"
  [ -f "$f" ] || return 0
  local rel="${f#$REPO_ROOT/}"
  local hit=0
  for pat in "${FORBIDDEN_PATTERNS[@]}"; do
    # grep -P が無くても -E で十分。-n で行番号、-i で大小区別なし。
    if matches="$(grep -niE "$pat" "$f" 2>/dev/null)"; then
      while IFS= read -r m; do
        [ -z "$m" ] && continue
        echo "[FAIL] $rel: $m"
        hit=1
      done <<< "$matches"
    fi
  done
  return $hit
}

FAIL=0

# current.json は blocked=true の blocked_reason に省略理由を書いて停止する正当な用途があるため、
# blocked=true の場合は対象外（人手介入待ちなのでクローズしていない）。
maybe_scan_current() {
  local f="$STATE_DIR/current.json"
  [ -f "$f" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    local blocked
    blocked="$(jq -r '.blocked // false' "$f" 2>/dev/null)"
    if [ "$blocked" = "true" ]; then
      echo "[INFO] current.json は blocked=true のためスキップ語検査の対象外（人手介入待ちで停止中）。"
      return 0
    fi
  fi
  scan_file "$f" || FAIL=1
}

if [ -n "$TARGET" ]; then
  # 対象指定モード: 特定 attestation/loop/tasks のみ走査
  for f in \
    "$STATE_DIR/attestations/${TARGET}.json" \
    "$STATE_DIR/loops/${TARGET}.json" \
    "$STATE_DIR/tasks/${TARGET}.json"; do
    scan_file "$f" || FAIL=1
  done
else
  # 全体モード
  scan_file "$AUTODEV_DIR/開発進捗状況.md" || FAIL=1
  for d in loops attestations persona_tests; do
    for f in "$STATE_DIR/$d"/*.json; do
      [ -f "$f" ] || continue
      scan_file "$f" || FAIL=1
    done
  done
  maybe_scan_current
fi

if [ "$FAIL" = "1" ]; then
  echo
  echo "[FAIL] 言い訳語ゲート NG。CLAUDE_MAIN.md 規約12〜14 違反の疑い。"
  echo "  - フェーズ・ステップを「時間制約」「後続作業」「将来対応」「省略」等の理由で打ち切ってはいけません。"
  echo "  - 実施不能なら current.json::blocked=true + blocked_reason 明記で人手介入待ち停止が正規ルート。"
  echo "  - 修正・追加実装を切り出すなら autodev/inputs/修正対応/修正_<理由>.md を生成して修正ループへ。"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] 言い訳語ゲート PASS（スキップ宣言の混入なし）"
exit 0
