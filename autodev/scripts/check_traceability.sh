#!/usr/bin/env bash
# 要件↔設計↔タスク↔実装ファイル 四者トレーサビリティ・ゲート
# （FR-5.21.2 / FR-5.21.3 / F5.5 / R5.5）。
#
# 1機能（または1修正）の要件項目すべてが、設計書・タスク（layer 含む）・実装ファイルへと
# 連鎖して紐付いていることを機械検査する。Android 固有の検査として:
#   - layer × カテゴリ マッピング（画面要素=ui / データモデル=data 等）
#   - testTag 候補 grep（要件書「画面要素」→ app/src/main/.../ui/）
#   - Room Entity ファイル存在（要件書「データモデル」→ app/src/main/.../data/entity/）
#   - Maestro flow / androidTest 存在（要件書「受け入れ条件」→ maestro/ or app/src/androidTest/）
# を行う。
#
# 既存出力 JSON があれば covered_by_ai / ai_reason を (category, item) 一致で承継する
# （FR-5.5.5 ground-truth 補完 / FR-5.21.2.5）。
#
# 使い方:
#   check_traceability.sh <対象名> [--scope feature|fix] [--input <md>] \
#                                  [--design <md>] [--gate] [--cycle <N>] \
#                                  [--out <state/traceability/<対象名>.json>]
#
# 既定:
#   --scope    feature
#   --input    autodev/inputs/要件定義/機能要件_<対象名>.md
#                  (scope=fix なら autodev/inputs/修正対応/修正_<対象名>.md)
#   --design   docs/設計/features/<対象名>.md
#   --out      autodev/state/traceability/<対象名>.json
#   --cycle    1
#
# 終了コード:
#   0 = PASS / 1 = FAIL（--gate 指定時のみ）/ 2 = 入力不正
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

command -v jq >/dev/null 2>&1 || { echo "[FAIL] jq が必要です"; exit 2; }

TARGET="${1:-}"
shift || true
[ -z "$TARGET" ] && { echo "[FAIL] 対象名を指定してください"; exit 2; }

SCOPE="feature"
INPUT=""
DESIGN=""
GATE=0
CYCLE=1
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --scope)  SCOPE="$2"; shift 2 ;;
    --input)  INPUT="$2"; shift 2 ;;
    --design) DESIGN="$2"; shift 2 ;;
    --gate)   GATE=1; shift ;;
    --cycle)  CYCLE="$2"; shift 2 ;;
    --out)    OUT="$2"; shift 2 ;;
    *) echo "[FAIL] 不明オプション: $1"; exit 2 ;;
  esac
done

case "$SCOPE" in
  feature|fix) ;;
  *) echo "[FAIL] --scope は feature または fix"; exit 2 ;;
esac

# --- 既定パス解決 ---
if [ -z "$INPUT" ]; then
  if [ "$SCOPE" = "feature" ]; then
    CAND="$AUTODEV_DIR/inputs/要件定義/機能要件_${TARGET}.md"
    [ -f "$CAND" ] && INPUT="$CAND"
    if [ -z "$INPUT" ] && [ -f "$AUTODEV_DIR/inputs/要件定義/要件定義書.md" ]; then
      INPUT="$AUTODEV_DIR/inputs/要件定義/要件定義書.md"
    fi
  else
    CAND="$AUTODEV_DIR/inputs/修正対応/修正_${TARGET}.md"
    [ -f "$CAND" ] && INPUT="$CAND"
  fi
fi

if [ -z "$DESIGN" ]; then
  if [ "$SCOPE" = "feature" ]; then
    DESIGN="$REPO_ROOT/docs/設計/features/${TARGET}.md"
  fi
fi

TASKS="$STATE_DIR/tasks/${TARGET}.json"
[ -f "$TASKS" ] || { echo "[FAIL] tasks/${TARGET}.json が存在しません"; exit 2; }

# --- ui_required の確認（system.json から / DB 基盤など UI なし機能の例外用） ---
# jq の `// "true"` は false 値も置換してしまうため、boolean を直接判定する。
UI_REQUIRED="true"
SYS_JSON="$STATE_DIR/loops/system.json"
if [ -f "$SYS_JSON" ] && [ "$SCOPE" = "feature" ]; then
  v="$(jq -r --arg t "$TARGET" '.features[]? | select(.id==$t or .name==$t) | (.ui_required == false)' "$SYS_JSON" 2>/dev/null)"
  [ "$v" = "true" ] && UI_REQUIRED="false"
fi

# --- 要件項目を抽出 ---
# 受け入れ条件 / 画面要素 / ユーザー操作 / エラーケース / データモデル / API / 影響範囲のリスト項目（- xxx）を抽出
# ui_required=false の機能では「画面要素」「ユーザー操作」をスキップ（DB 基盤等の正常パターン / FR-5.21.2.4）
extract_requirement_items() {
  local f="$1"
  local ui_req="${2:-true}"
  [ -f "$f" ] || return 0
  awk -v UI_REQ="$ui_req" '
    /^##+/ {
      line=$0
      sub(/^#+[[:space:]]*/,"",line)
      sub(/^[0-9]+\.[[:space:]]*/,"",line)
      category=""
      if (line ~ /画面要素/)               category="画面要素"
      else if (line ~ /ユーザー操作/)      category="ユーザー操作"
      else if (line ~ /エラーケース/)      category="エラーケース"
      else if (line ~ /データモデル/)      category="データモデル"
      else if (line ~ /受け入れ条件/)      category="受け入れ条件"
      else if (line ~ /API/)               category="API"
      else if (line ~ /影響範囲/)          category="影響範囲"
      # ui_required=false の機能では UI 関連項目をスキップ（DB 基盤等の正常パターン）
      if (UI_REQ == "false" && (category=="画面要素" || category=="ユーザー操作")) category=""
      next
    }
    /^[[:space:]]*-[[:space:]]+/ {
      if (category=="") next
      item=$0
      sub(/^[[:space:]]*-[[:space:]]+/,"",item)
      sub(/[[:space:]]+$/,"",item)
      if (length(item) < 2) next
      # ガイド文（「（UI 要素の列挙」「優先度: 高 / 中 / 低」等）は除外
      if (item ~ /UI 要素の列挙|追加するエンティティ|追加する Room|追加する Entity|Given\/When\/Then 形式|優先度: *高|理由:/) next
      printf "%s\t%s\n", category, item
    }
  ' "$f"
}

REQ_ITEMS_TSV="$(mktemp)"
if [ -n "$INPUT" ] && [ -f "$INPUT" ]; then
  extract_requirement_items "$INPUT" "$UI_REQUIRED" > "$REQ_ITEMS_TSV"
fi

# --- 設計書セクション一覧 ---
DESIGN_SECTIONS=()
if [ -n "$DESIGN" ] && [ -f "$DESIGN" ]; then
  while IFS= read -r s; do
    DESIGN_SECTIONS+=("$s")
  done < <(grep -E '^##[^#]' "$DESIGN" | sed 's/^##[[:space:]]*//' || true)
fi

# --- testTag 候補抽出（画面要素カテゴリのみ） ---
# パターン: (testTag: xxx) または testTag: xxx。「例: ...」「例 ...」で始まる行は除外
extract_testtag_candidates_from_input() {
  local f="$1"
  [ -f "$f" ] || return 0
  grep -vE '^\s*-\s*[（(]?例[:：\s]' "$f" 2>/dev/null \
    | grep -oE '[(（]?\s*testTag\s*[:：]\s*[a-z_][a-z0-9_]*' \
    | sed -E 's/^[(（]?\s*testTag\s*[:：]\s*//' \
    | sort -u
}

# --- 各要件項目について実装証跡をスキャン ---
SCAN_ROOTS_MAIN=("$APP_DIR/src/main")
SCAN_ROOTS_TEST=("$APP_DIR/src/androidTest" "$APP_DIR/src/test" "$MAESTRO_DIR")

scan_grep_token() {
  local q="$1"; shift
  local roots=("$@")
  local token
  token="$(echo "$q" | grep -oE '/[A-Za-z0-9_./-]+|[A-Za-z][A-Za-z0-9_]{2,}' | head -1)"
  [ -z "$token" ] && return 1
  local existing=()
  for r in "${roots[@]}"; do
    [ -d "$r" ] && existing+=("$r")
  done
  [ "${#existing[@]}" = "0" ] && return 1
  grep -rIlF --binary-files=without-match -- "$token" "${existing[@]}" 2>/dev/null | head -3
}

# scan_testtag_hits <candidate>:Modifier.testTag("候補") が grep で見つかるか
scan_testtag_hits() {
  local cand="$1"
  [ -d "$APP_DIR/src/main" ] || return 1
  grep -rIlE --binary-files=without-match \
    "[Mm]odifier\.testTag\s*\(\s*\"${cand}\"\s*\)" \
    "$APP_DIR/src/main" 2>/dev/null | head -3
}

# scan_entity_files <item>: 大文字始まりのトークンを Entity 名とみなして app/src/main/.../data/ で grep
scan_entity_files() {
  local item="$1"
  local token
  token="$(echo "$item" | grep -oE '[A-Z][A-Za-z0-9_]+' | head -1)"
  [ -z "$token" ] && return 1
  [ -d "$APP_DIR/src/main" ] || return 1
  grep -rIlE --binary-files=without-match \
    "(class|object|@Entity)\s+${token}\b|@Entity\(.*\"${token}\"" \
    "$APP_DIR/src/main" 2>/dev/null | head -3
}

# scan_test_files <target>: maestro と androidTest で対象名・testTag を含むファイル
scan_test_files() {
  local target="$1"
  local files=()
  for r in "$MAESTRO_DIR" "$APP_DIR/src/androidTest"; do
    [ -d "$r" ] || continue
    while IFS= read -r f; do
      [ -n "$f" ] && files+=("$f")
    done < <(grep -rIlE --binary-files=without-match -- "$target" "$r" 2>/dev/null | head -3)
  done
  printf '%s\n' "${files[@]+"${files[@]}"}" | grep -v '^$' || true
}

# task_ids_for_category <category>: design_doc_ref.section にカテゴリ名が含まれるタスク ID
task_ids_for_category() {
  local cat="$1"
  jq -c --arg cat "$cat" \
    '[.tasks[] | select(.design_doc_ref.section // "" | test($cat))] | map(.id)' \
    "$TASKS" 2>/dev/null
}

# task_layers_for_ids <ids_json>: タスク ID 配列から layer の集合を返す
task_layers_for_ids() {
  local ids="$1"
  jq -c --argjson ids "$ids" \
    '[.tasks[] | select(.id as $i | $ids | index($i)) | .layer // "unknown"] | unique' \
    "$TASKS" 2>/dev/null
}

# expected_layers_for <category> <ui_required>: 期待 layer 集合（JSON 配列文字列）。
# ui_required=false 機能の画面要素/ユーザー操作は extract_requirement_items で抽出済みでないため
# ここに到達しないが、念のため [] を返す。影響範囲は scope=fix 主眼で layer 不問。
expected_layers_for() {
  local cat="$1" ui_req="$2"
  case "$cat" in
    画面要素)
      [ "$ui_req" = "false" ] && echo '[]' || echo '["ui"]' ;;
    ユーザー操作)
      [ "$ui_req" = "false" ] && echo '[]' || echo '["ui","viewmodel"]' ;;
    エラーケース)        echo '["ui","viewmodel","domain"]' ;;
    データモデル)        echo '["data"]' ;;
    受け入れ条件)        echo '["test"]' ;;
    API)                 echo '["data","domain"]' ;;
    影響範囲)            echo '[]' ;;   # scope=fix 主眼 / layer 不問・implementation 確認のみ
    *)                   echo '[]' ;;
  esac
}

# layer_matches_expected <task_layers_json> <expected_layers_json>: いずれかにマッチで true
layer_matches_expected() {
  local task_layers="$1" expected="$2"
  echo "$task_layers" | jq -e --argjson exp "$expected" \
    'any(.[]; . as $l | $exp | index($l))' >/dev/null 2>&1
}

# --- 既存出力からの covered_by_ai / ai_reason 承継 ---
if [ -z "$OUT" ]; then
  OUT="$STATE_DIR/traceability/${TARGET}.json"
fi
PREV_JSON="$OUT"
prev_lookup() {
  [ -f "$PREV_JSON" ] || { echo ""; return; }
  jq -c --arg c "$1" --arg i "$2" \
    '.items[]? | select(.category==$c and .item==$i)' "$PREV_JSON" 2>/dev/null | head -1
}

ROWS_JSON="$(mktemp)"
echo "[]" > "$ROWS_JSON"

GAP_COUNT=0
TOTAL_COUNT=0

while IFS=$'\t' read -r category item; do
  [ -z "$category" ] && continue
  [ -z "$item" ] && continue
  TOTAL_COUNT="$((TOTAL_COUNT + 1))"

  # 設計セクションマッチ
  design_ref=""
  for s in "${DESIGN_SECTIONS[@]+"${DESIGN_SECTIONS[@]}"}"; do
    case "$s" in
      *"$category"*) design_ref="$s"; break ;;
    esac
  done

  # タスク ID と layer
  task_ids="$(task_ids_for_category "$category")"
  [ -z "$task_ids" ] && task_ids="[]"
  task_layers="$(task_layers_for_ids "$task_ids")"
  [ -z "$task_layers" ] && task_layers="[]"

  # 期待 layer
  expected_layers="$(expected_layers_for "$category" "$UI_REQUIRED")"

  # layer マッチ判定
  layer_ok="false"
  if [ "$expected_layers" = "[]" ]; then
    layer_ok="true"  # ui_required=false で UI/操作カテゴリは検査スキップ
  elif layer_matches_expected "$task_layers" "$expected_layers"; then
    layer_ok="true"
  fi

  # 実装証跡
  files_arr="[]"
  case "$category" in
    画面要素|ユーザー操作|エラーケース)
      [ "$UI_REQUIRED" = "false" ] && [ "$category" != "エラーケース" ] || {
        files="$(scan_grep_token "$item" "${SCAN_ROOTS_MAIN[@]}" || true)"
        files_arr="$(printf '%s\n' "$files" | jq -R . | jq -s 'map(select(length>0))')"
      }
      ;;
    データモデル)
      files="$(scan_entity_files "$item" || true)"
      files_arr="$(printf '%s\n' "$files" | jq -R . | jq -s 'map(select(length>0))')"
      ;;
    受け入れ条件)
      files="$(scan_test_files "$TARGET" || true)"
      files_arr="$(printf '%s\n' "$files" | jq -R . | jq -s 'map(select(length>0))')"
      ;;
    影響範囲)
      # 修正対応書の影響範囲項目はファイルパス or ファイル名を含むことが多い。
      # まずパス文字列を直接マッチさせ、ヒットしなければ token grep にフォールバック。
      files=""
      path_token="$(echo "$item" | grep -oE '[A-Za-z_][A-Za-z0-9_./-]+\.[A-Za-z]+' | head -1)"
      if [ -n "$path_token" ]; then
        # ファイル名（basename）で grep
        base_token="$(basename "$path_token" | sed 's/\.[^.]*$//')"
        files="$(grep -rIlE --binary-files=without-match --include='*.kt' --include='*.kts' --include='*.yaml' --include='*.xml' \
          -- "$base_token" "$APP_DIR/src" "$MAESTRO_DIR" 2>/dev/null | head -3)"
      fi
      [ -z "$files" ] && files="$(scan_grep_token "$item" "${SCAN_ROOTS_MAIN[@]}" || true)"
      files_arr="$(printf '%s\n' "$files" | jq -R . | jq -s 'map(select(length>0))')"
      ;;
    *)
      files="$(scan_grep_token "$item" "${SCAN_ROOTS_MAIN[@]}" || true)"
      files_arr="$(printf '%s\n' "$files" | jq -R . | jq -s 'map(select(length>0))')"
      ;;
  esac

  # 画面要素カテゴリの testTag 候補抽出と grep
  tt_cand_arr="[]"
  tt_hits_arr="[]"
  if [ "$category" = "画面要素" ] && [ "$UI_REQUIRED" != "false" ] && [ -n "$INPUT" ]; then
    cand="$(echo "$item" | grep -oE '[(（]?\s*testTag\s*[:：]\s*[a-z_][a-z0-9_]*' | sed -E 's/^[(（]?\s*testTag\s*[:：]\s*//' | head -1)"
    if [ -n "$cand" ]; then
      tt_cand_arr="$(echo "$cand" | jq -R . | jq -s 'map(select(length>0))')"
      hits="$(scan_testtag_hits "$cand" || true)"
      tt_hits_arr="$(printf '%s\n' "$hits" | jq -R . | jq -s 'map(select(length>0))')"
    fi
  fi

  # covered 判定: design_ref / task_ids / files / layer_ok のすべて
  covered="false"
  if [ -n "$design_ref" ] \
     && [ "$task_ids" != "[]" ] \
     && [ "$(echo "$files_arr" | jq 'length')" -gt 0 ] \
     && [ "$layer_ok" = "true" ]; then
    covered="true"
  fi

  # 前回出力の AI 補完承継
  prev_entry="$(prev_lookup "$category" "$item")"
  covered_by_ai="false"
  ai_reason=""
  if [ -n "$prev_entry" ]; then
    if [ "$(echo "$prev_entry" | jq -r '.covered_by_ai // false')" = "true" ]; then
      covered_by_ai="true"
      ai_reason="$(echo "$prev_entry" | jq -r '.ai_reason // ""')"
    fi
  fi

  effective_covered="$covered"
  [ "$covered_by_ai" = "true" ] && effective_covered="true"
  [ "$effective_covered" = "false" ] && GAP_COUNT="$((GAP_COUNT + 1))"

  ROWS_JSON_TMP="$(mktemp)"
  jq --arg c "$category" --arg i "$item" --arg d "$design_ref" \
     --argjson t "$task_ids" --argjson tl "$task_layers" \
     --argjson el "$expected_layers" \
     --argjson f "$files_arr" \
     --argjson ttc "$tt_cand_arr" --argjson tth "$tt_hits_arr" \
     --arg cov "$covered" --arg cba "$covered_by_ai" --arg reason "$ai_reason" \
     --arg lok "$layer_ok" \
     '. + [{
        category: $c,
        item: $i,
        expected_layers: $el,
        design_section: $d,
        task_ids: $t,
        task_layers: $tl,
        layer_match: ($lok == "true"),
        implementation_evidence: $f,
        testtag_candidates: $ttc,
        testtag_hits: $tth,
        covered: ($cov == "true"),
        covered_by_ai: ($cba == "true"),
        ai_reason: $reason
      }]' "$ROWS_JSON" > "$ROWS_JSON_TMP"
  mv "$ROWS_JSON_TMP" "$ROWS_JSON"
done < "$REQ_ITEMS_TSV"

rm -f "$REQ_ITEMS_TSV"

mkdir -p "$(dirname "$OUT")"
PASSED="true"
[ "$GAP_COUNT" -gt 0 ] && PASSED="false"

AI_PASS_COUNT="$(jq '[.[] | select(.covered_by_ai==true and .covered==false)] | length' "$ROWS_JSON")"

TMP="$(mktemp)"
jq -n \
  --arg target "$TARGET" \
  --arg scope "$SCOPE" \
  --arg checked_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg input "${INPUT#$REPO_ROOT/}" \
  --arg design "${DESIGN#$REPO_ROOT/}" \
  --arg ui_required "$UI_REQUIRED" \
  --argjson cycle "$CYCLE" \
  --argjson total "$TOTAL_COUNT" \
  --argjson gaps "$GAP_COUNT" \
  --argjson ai_pass "$AI_PASS_COUNT" \
  --arg passed "$PASSED" \
  --slurpfile rows "$ROWS_JSON" \
  '{
     target: $target,
     scope: $scope,
     scanned_at: $checked_at,
     cycle: $cycle,
     input: $input,
     design: $design,
     ui_required: ($ui_required == "true"),
     items_total: $total,
     items_with_gap: $gaps,
     items_with_ai_pass: $ai_pass,
     items: $rows[0],
     passed: ($passed == "true")
   }' > "$TMP"
mv "$TMP" "$OUT"
rm -f "$ROWS_JSON"

# --- レポート ---
echo "[INFO] 対象: $TARGET / scope: $SCOPE / ui_required: $UI_REQUIRED"
echo "[INFO] 要件項目: $TOTAL_COUNT / ギャップ: $GAP_COUNT / AI 補完 PASS: $AI_PASS_COUNT"
echo "[INFO] 出力: $OUT"

if [ "$PASSED" = "true" ]; then
  echo "[OK] 要件↔設計↔タスク↔実装 トレーサビリティ PASS"
  exit 0
fi

echo "[FAIL] トレーサビリティ・ギャップを検出（items_with_gap=$GAP_COUNT）"
jq -r '.items[] | select((.covered or .covered_by_ai)==false) | "  - [" + .category + "] " + .item' "$OUT"

[ "$GATE" = "1" ] && exit 1 || exit 0
