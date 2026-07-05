#!/usr/bin/env bash
# autodev/開発進捗状況.md を state/ から再生成する（FR-5.6.7 / 付録D）。
# state が空（雛形時点）なら「初期状態（未着手）」版を生成する。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SYS="$STATE_DIR/loops/system.json"
NOW="$(date '+%Y-%m-%d %H:%M:%S%z' 2>/dev/null || date)"
TMP="$(mktemp "${PROGRESS_MD%/*}/.progress.XXXXXX")"

emoji() { case "$1" in done) echo "✅ done";; in_progress|wip) echo "🔄 wip";; *) echo "⏳ pending";; esac; }

if ! command -v jq >/dev/null 2>&1 || [ ! -f "$SYS" ]; then
  # ---- 初期状態（state 未生成） ----
  cat > "$TMP" <<EOF
# AutoDev for Android 開発進捗状況

最終更新: $NOW
モード: -
現在のフェーズ: 初期状態（未着手）
ブロッカー: なし

---

## 一行サマリ

まだ自動開発は開始されていません。\`autodev/inputs/\` に入力ファイルを配置し、
\`claude --dangerously-skip-permissions\` で起動して開発を開始してください。

---

## 次に AI が行うアクション

1. 起動プロンプト（3形態のいずれか）を受信する。
2. 入力ファイルを読み込み、対応するループ skill を発動する。
3. state を生成し、本ファイルを再生成する。

---

## 主要状態ファイル参照

- システムループ: autodev/state/loops/system.json （未生成）
EOF
  mv "$TMP" "$PROGRESS_MD"
  exit 0
fi

# ---- state あり: system.json から要約 ----
MODE="$(jq -r '.input_file // "-"' "$SYS")"
PHASE="$(jq -r '.current_phase // "-"' "$SYS")"
STATUS="$(jq -r '.status // "-"' "$SYS")"
TOTAL="$(jq -r '.features | length' "$SYS" 2>/dev/null || echo 0)"
DONE="$(jq -r '[.features[]? | select(.status=="done")] | length' "$SYS" 2>/dev/null || echo 0)"
PCT=0; [ "$TOTAL" -gt 0 ] && PCT=$(( DONE * 100 / TOTAL ))

{
  echo "# AutoDev for Android 開発進捗状況"
  echo
  echo "最終更新: $NOW"
  echo "モード: システム全体開発（入力: $MODE）"
  echo "現在のフェーズ: $PHASE"
  echo "全体状態: $STATUS"
  echo "ブロッカー: なし"
  echo
  echo "---"
  echo
  echo "## 一行サマリ"
  echo
  echo "機能 ${DONE}/${TOTAL} 完了（${PCT}%）。フェーズ: ${PHASE}。"
  echo
  echo "---"
  echo
  echo "## システムループ進捗（S1〜S15）"
  echo
  echo "| フェーズ | 状態 |"
  echo "|---|---|"
  # S1〜S8 はまとめて features 抽出済みなら done 表示
  if [ "$TOTAL" -gt 0 ]; then
    echo "| S1 要件整理 | ✅ done |"
    echo "| S2 機能リスト抽出 | ✅ done |"
    echo "| S3 ペルソナ定義 | $([ -f "$STATE_DIR/personas/personas.json" ] && echo '✅ done' || echo '⏳ pending') |"
    echo "| S4 全体設計書作成 | $([ -f "$REPO_ROOT/docs/設計/全体設計書.md" ] && echo '✅ done' || echo '⏳ pending') |"
    echo "| S5 機能リスト補完 | ✅ done |"
    echo "| S6 依存順ソート | ✅ done |"
    # S6.5 (FR-5.21.1): s6_5_result.passed=true で done / 無効化されていれば -
    S65_STATUS="$(jq -r 'if .s6_5_result == null then "-" elif .s6_5_result.passed == true then "✅ done" else "🔄 wip" end' "$SYS" 2>/dev/null || echo '⏳ pending')"
    echo "| S6.5 要件↔設計カバレッジ確認 | $S65_STATUS |"
    echo "| S7 ペルソナテスト計画 | ✅ done |"
    echo "| S8 state 記録 | ✅ done |"
    echo "| S9 機能ループ実行 | $([ "$DONE" -lt "$TOTAL" ] && echo '🔄 wip' || echo '✅ done') |"
  else
    for s in "S1 要件整理" "S2 機能リスト抽出" "S3 ペルソナ定義" "S4 全体設計書作成" "S5 機能リスト補完" "S6 依存順ソート" "S6.5 要件↔設計カバレッジ確認" "S7 ペルソナテスト計画" "S8 state 記録" "S9 機能ループ実行"; do
      echo "| $s | ⏳ pending |"
    done
  fi
  echo "| S10 全体結合確認・改善 | $([ -f "$STATE_DIR/attestations/integration.json" ] && echo '✅ done' || echo '⏳ pending') |"
  echo "| S11 UIデザイン改善 | $([ -f "$STATE_DIR/attestations/ui_polish.json" ] && echo '✅ done' || echo '⏳ pending') |"
  echo "| S12 全体スモーク | $(jq -e '.smoke_evidence // empty' "$STATE_DIR/attestations/system.json" >/dev/null 2>&1 && echo '✅ done' || echo '⏳ pending') |"
  echo "| S13 顧客向けドキュメント | $([ -f "$REPO_ROOT/README.md" ] && [ -f "$REPO_ROOT/docs/操作手順書.md" ] && [ -f "$REPO_ROOT/docs/インストール手順.md" ] && echo '✅ done' || echo '⏳ pending') |"
  echo "| S14 リリース最終確認 | $([ -f "$STATE_DIR/attestations/release.json" ] && echo '✅ done' || echo '⏳ pending') |"
  echo "| S15 完了報告 | $([ "$STATUS" = "completed" ] && echo '✅ done' || echo '⏳ pending') |"
  echo
  echo "---"
  echo
  echo "## 機能リスト進捗"
  echo
  echo "| # | 機能名 | 状態 | attestation | persona_test_ref | F5.5 (gap/AI補完) |"
  echo "|---|---|---|---|---|---|"
  # features の各行に対し、attestation を開いて persona_test_ref / traceability を抽出する。
  # attestation 不在または持たない場合は "-" を表示（F6.5 / F5.5 がスキップされた機能含む）。
  jq -c '.features // [] | to_entries[]' "$SYS" 2>/dev/null \
    | while IFS= read -r entry; do
        idx="$(echo "$entry" | jq -r '.key + 1')"
        name="$(echo "$entry" | jq -r '.value.name')"
        st="$(echo "$entry" | jq -r '.value.status')"
        att="$(echo "$entry" | jq -r '.value.attestation // "-"')"
        ptr="-"
        trace="-"
        if [ "$att" != "-" ] && [ -f "$REPO_ROOT/$att" ]; then
          v="$(jq -r '.persona_test_ref // empty' "$REPO_ROOT/$att" 2>/dev/null || true)"
          [ -n "$v" ] && ptr="$v"
          # F5.5 トレーサビリティ表示 (FR-5.21.2.9)
          tp="$(jq -r '.traceability_passed // empty' "$REPO_ROOT/$att" 2>/dev/null || true)"
          tr="$(jq -r '.traceability_ref // empty' "$REPO_ROOT/$att" 2>/dev/null || true)"
          if [ "$tp" = "true" ] && [ -n "$tr" ] && [ -f "$REPO_ROOT/$tr" ]; then
            gap="$(jq -r '.items_with_gap // 0' "$REPO_ROOT/$tr" 2>/dev/null || echo 0)"
            aip="$(jq -r '.items_with_ai_pass // 0' "$REPO_ROOT/$tr" 2>/dev/null || echo 0)"
            trace="✅ ${gap}/${aip}"
          elif [ "$tp" = "true" ]; then
            trace="✅ skip"
          elif [ -n "$tp" ]; then
            trace="❌ fail"
          fi
        fi
        printf '| %s | %s | %s | %s | %s | %s |\n' "$idx" "$name" "$(emoji "$st")" "$att" "$ptr" "$trace"
      done
  echo
  echo "---"
  echo
  echo "## ペルソナテスト履歴"
  echo
  echo "| # | scope | target | triggered_from | 実施日時 | result | 残課題 |"
  echo "|---|---|---|---|---|---|---|"
  for f in "$STATE_DIR"/persona_tests/*.json; do
    [ -f "$f" ] || continue
    jq -r '"| \(.test_number // .number) | \(.scope // "system") | \(.target // "-") | \(.triggered_from // .trigger // "-") | \(.executed_at // "-") | \(.result // "-") | \((.blocking_issues // []) | length) |"' "$f" 2>/dev/null || true
  done
  echo
  echo "---"
  echo
  echo "## 主要状態ファイル参照"
  echo
  echo "- システムループ: autodev/state/loops/system.json"
  echo "- ペルソナ定義: autodev/state/personas/personas.json"
} > "$TMP"

mv "$TMP" "$PROGRESS_MD"
exit 0
