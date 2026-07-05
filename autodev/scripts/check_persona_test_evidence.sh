#!/usr/bin/env bash
# 機能ループ F7 / 修正ループ R7 のクローズゲート（Android 版）。
# 当該機能名・修正名に対する最新のペルソナテスト attestation が
#   - result == "completed"
#   - blocking_issues == []
# を満たしているかを検証する（FR-5.9.8 / FR-5.9.9）。
#
# 使い方:
#   check_persona_test_evidence.sh <対象名> <scope>
#     <対象名>: 機能名 または 修正名
#     <scope> : feature | fix
#
# loop.yaml の `<scope>_loop.persona_test_enabled: false` の場合は SKIP（exit 0）とする。
# また、修正ループの場合に `r6_5_skipped: true` の attestation 既出があれば SKIP も PASS 扱い。
#
# 終了コード:
#   0 = PASS（または無効化により SKIP）
#   1 = NG（ゲート fail）
#   2 = 引数不正
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

usage() {
  sed -n '2,16p' "$0"
}

TARGET="${1:-}"
SCOPE="${2:-}"
if [ -z "$TARGET" ] || [ -z "$SCOPE" ]; then
  usage; exit 2
fi
case "$SCOPE" in
  feature|fix) ;;
  *) log_error "scope は feature か fix のみ。指定: $SCOPE"; exit 2 ;;
esac

LOOP_YAML="$AUTODEV_DIR/config/loop.yaml"

# loop.yaml の persona_test_enabled を雑に判定（python なしでも grep で読む）
ENABLED_KEY="${SCOPE}_loop"
ENABLED_LINE="$(awk -v sec="^${ENABLED_KEY}:" '
  $0 ~ sec {inblk=1; next}
  inblk==1 && /^[^[:space:]#]/ {inblk=0}
  inblk==1 && /persona_test_enabled:/ {print; exit}
' "$LOOP_YAML" 2>/dev/null || true)"
if echo "$ENABLED_LINE" | grep -qE 'persona_test_enabled:[[:space:]]*false'; then
  log_info "[$SCOPE:$TARGET] ${ENABLED_KEY}.persona_test_enabled=false のため SKIP（PASS 扱い）"
  exit 0
fi

PT_DIR="$STATE_DIR/persona_tests"
if [ ! -d "$PT_DIR" ]; then
  log_error "ペルソナテスト state ディレクトリが存在しません: $PT_DIR"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  log_error "jq が必要ですがインストールされていません。"
  exit 1
fi

# 対象スコープに一致する最新の attestation を探す（B.7 形式: .scope=feature|fix, .target=<名>）。
# 最新判定は .test_number の数値降順。文字列辞書順だと "9" > "10" となり誤判定するため
# 必ず数値比較する（test_number は B.7 で必須・整数 / 全 scope 通し連番）。
LATEST=""
LATEST_NUM=-1
while IFS= read -r -d '' f; do
  s="$(jq -r '.scope // empty' "$f" 2>/dev/null || true)"
  t="$(jq -r '.target // empty' "$f" 2>/dev/null || true)"
  if [ "$s" = "$SCOPE" ] && [ "$t" = "$TARGET" ]; then
    num="$(jq -r '.test_number // 0' "$f" 2>/dev/null || echo 0)"
    [[ "$num" =~ ^[0-9]+$ ]] || num=0
    if [ "$num" -gt "$LATEST_NUM" ]; then
      LATEST="$f"; LATEST_NUM="$num"
    fi
  fi
done < <(find "$PT_DIR" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)

if [ -z "$LATEST" ]; then
  log_error "[$SCOPE:$TARGET] 対象のペルソナテスト attestation が見つかりません。F6.5/R6.5 を実行してください。"
  exit 1
fi

log_info "[$SCOPE:$TARGET] 最新 attestation: $LATEST"

# scope=fix の R6.5 スキップ条件②③（severity 足切り / source_scope による無限ループ防止）に
# 該当した場合は attestation に r6_5_skipped: true が記録されており、これは PASS 扱い。
SKIPPED="$(jq -r '.r6_5_skipped // false' "$LATEST" 2>/dev/null || echo false)"
if [ "$SCOPE" = "fix" ] && [ "$SKIPPED" = "true" ]; then
  REASON="$(jq -r '.r6_5_skip_reason // "unspecified"' "$LATEST")"
  log_info "[fix:$TARGET] R6.5 は AI 判定でスキップされました（reason=$REASON）。PASS 扱い。"
  exit 0
fi

RESULT="$(jq -r '.result // empty' "$LATEST")"
BLOCKING_COUNT="$(jq '(.blocking_issues // []) | length' "$LATEST")"

if [ "$RESULT" != "completed" ]; then
  log_error "result が completed ではありません: $RESULT"
  exit 1
fi
if [ "$BLOCKING_COUNT" -gt 0 ]; then
  log_error "blocking_issues が $BLOCKING_COUNT 件残っています（F7/R7 クローズ不可）"
  jq '.blocking_issues' "$LATEST" >&2
  exit 1
fi

log_info "[$SCOPE:$TARGET] ペルソナテスト attestation PASS"
exit 0
