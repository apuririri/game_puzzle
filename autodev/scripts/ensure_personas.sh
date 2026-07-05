#!/usr/bin/env bash
# autodev/state/personas/personas.json の存在と最低人数を保証する補助スクリプト。
# 機能ループ F6.5 / 修正ループ R6.5 のペルソナテスト発動前に呼び出される（FR-5.9.1 改訂 / Android 版）。
#
# 使い方:
#   ensure_personas.sh                  # 既定（最低3体）
#   ensure_personas.sh --min 3 --max 5  # 既定レンジを明示
#
# 終了コード:
#   0  : personas.json が存在し、最低人数を満たしている（再利用可能）
#   2  : personas.json が不在、または最低人数を下回る（AI による定義/補充が必要）
#   1  : 解析失敗（jq エラー等）
#
# AI への合図:
#   - 終了 2 のとき、本スクリプトは作成・編集を行わない。
#     呼び出し元 skill（autodev-persona-test）が当該入力 md と既存設計書を入力に
#     ペルソナを定義し personas.json に書き込んだ上で再実行する。
#   - 既存 personas.json の ID は書き換え禁止（末尾追加のみ / FR-5.9.1 改訂）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MIN_COUNT=3
MAX_COUNT=5
while [ $# -gt 0 ]; do
  case "$1" in
    --min) MIN_COUNT="$2"; shift 2 ;;
    --max) MAX_COUNT="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    *) log_error "未知の引数: $1"; exit 1 ;;
  esac
done

PERSONAS_JSON="$STATE_DIR/personas/personas.json"

if [ ! -f "$PERSONAS_JSON" ]; then
  log_warn "personas.json が存在しません: $PERSONAS_JSON"
  log_warn "autodev-persona-test skill のフォールバック手順に従い、AI が定義してから再実行してください。"
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  log_warn "jq が見つからないため JSON 内容チェックをスキップし、ファイル存在のみで PASS とします。"
  log_info "personas.json 存在 OK: $PERSONAS_JSON"
  exit 0
fi

COUNT="$(jq '.personas | length' "$PERSONAS_JSON" 2>/dev/null || echo "")"
if [ -z "$COUNT" ] || ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
  log_error "personas.json の構造が不正です（.personas 配列が解析できません）。"
  exit 1
fi

if [ "$COUNT" -lt "$MIN_COUNT" ]; then
  log_warn "personas.json のペルソナ数 $COUNT が最低人数 $MIN_COUNT を下回ります。"
  log_warn "autodev-persona-test skill で不足分を追記（ID 末尾追加）してから再実行してください。"
  exit 2
fi

if [ "$COUNT" -gt "$MAX_COUNT" ]; then
  log_warn "personas.json のペルソナ数 $COUNT が既定上限 $MAX_COUNT を超えています（運用上は許容）。"
fi

log_info "personas.json OK: $COUNT 体（${MIN_COUNT}〜${MAX_COUNT} 推奨レンジ）"
exit 0
