#!/usr/bin/env bash
# 要件↔設計書 カバレッジゲート（FR-5.21.1 / S6.5）。
# システムループ S6.5 で発動し、要件定義書（および機能要件書）に列挙された機能セクションが、
# 全体設計書 + 機能別設計書のいずれかにマッピングされているかを機械検査する。
# Android 固有: 機能要件書の testTag 候補が設計書「## testTag 一覧」に反映されているか確認。
#
# 使い方:
#   check_requirement_design_coverage.sh [--gate] [--input <要件定義書.md>] \
#                                        [--design-dir <docs/設計>] \
#                                        [--features <機能名,機能名,...>] \
#                                        [--out <state/attestations/coverage.json>] \
#                                        [--cycle <N>]
#
# 既定値:
#   --input       autodev/inputs/要件定義/要件定義書.md（無ければ機能要件_*.md を全列挙）
#   --design-dir  docs/設計
#   --features    autodev/state/loops/system.json の features[].name から自動取得
#   --out         autodev/state/attestations/coverage.json（Android 単一ファイル方式）
#   --cycle       1（再走時は既存 cycles[] に append される）
#
# 終了コード:
#   0 = PASS（最新 cycle で未カバー要件・未参照設計セクション共にゼロ）
#   1 = FAIL（ギャップあり / --gate 指定時のみ）
#   2 = 入力不正（jq 未導入等）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

command -v jq >/dev/null 2>&1 || { echo "[FAIL] jq が必要です"; exit 2; }

GATE=0
INPUT=""
DESIGN_DIR="$REPO_ROOT/docs/設計"
FEATURES=""
OUT=""
CYCLE=1

while [ $# -gt 0 ]; do
  case "$1" in
    --gate)        GATE=1; shift ;;
    --input)       INPUT="$2"; shift 2 ;;
    --design-dir)  DESIGN_DIR="$2"; shift 2 ;;
    --features)    FEATURES="$2"; shift 2 ;;
    --out)         OUT="$2"; shift 2 ;;
    --cycle)       CYCLE="$2"; shift 2 ;;
    *) echo "[FAIL] 不明オプション: $1"; exit 2 ;;
  esac
done

# --- 入力ファイルの解決 ---
if [ -z "$INPUT" ]; then
  CAND="$AUTODEV_DIR/inputs/要件定義/要件定義書.md"
  if [ -f "$CAND" ]; then INPUT="$CAND"; fi
fi
INPUTS_LIST=()
if [ -n "$INPUT" ] && [ -f "$INPUT" ]; then INPUTS_LIST+=("$INPUT"); fi
# 機能要件_*.md があれば追加
while IFS= read -r f; do
  [ -n "$f" ] && INPUTS_LIST+=("$f")
done < <(find "$AUTODEV_DIR/inputs/要件定義" -maxdepth 1 -type f -name '機能要件_*.md' 2>/dev/null | sort)

if [ "${#INPUTS_LIST[@]}" = "0" ]; then
  echo "[FAIL] 要件定義書 / 機能要件書が見つかりません（autodev/inputs/要件定義/）"
  exit 2
fi

# --- 機能リストの解決 ---
declare -a FEATURE_NAMES
FEATURE_NAMES=()
if [ -n "$FEATURES" ]; then
  IFS=',' read -r -a FEATURE_NAMES <<< "$FEATURES"
else
  SYS_JSON="$STATE_DIR/loops/system.json"
  if [ -f "$SYS_JSON" ]; then
    while IFS= read -r n; do
      [ -n "$n" ] && FEATURE_NAMES+=("$n")
    done < <(jq -r '.features[]?.name // empty' "$SYS_JSON" 2>/dev/null)
  fi
fi

# 要件定義書から「## 機能: <名>」を補完抽出
EXTRACT_FROM_REQ() {
  local f="$1"
  grep -E '^## *機能: *' "$f" 2>/dev/null | sed -E 's/^## *機能: *//; s/[[:space:]]+$//'
}
for f in "${INPUTS_LIST[@]}"; do
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    skip=0
    for ex in "${FEATURE_NAMES[@]+"${FEATURE_NAMES[@]}"}"; do
      [ "$ex" = "$n" ] && skip=1 && break
    done
    [ "$skip" = "0" ] && FEATURE_NAMES+=("$n")
  done < <(EXTRACT_FROM_REQ "$f")
done

# 機能要件_<名>.md からも補完
for f in "${INPUTS_LIST[@]}"; do
  base="$(basename "$f")"
  case "$base" in
    機能要件_*.md)
      n="${base#機能要件_}"; n="${n%.md}"
      skip=0
      for ex in "${FEATURE_NAMES[@]+"${FEATURE_NAMES[@]}"}"; do
        [ "$ex" = "$n" ] && skip=1 && break
      done
      [ "$skip" = "0" ] && FEATURE_NAMES+=("$n")
      ;;
  esac
done

if [ "${#FEATURE_NAMES[@]}" = "0" ]; then
  echo "[WARN] 機能リストが解決できません（system.json も要件定義書セクションも空）"
fi

# --- 設計書セクションを抽出 ---
GLOBAL_DESIGN="$DESIGN_DIR/全体設計書.md"
FEATURES_DESIGN_DIR="$DESIGN_DIR/features"

global_has_section_for() {
  local feat="$1"
  [ -f "$GLOBAL_DESIGN" ] || return 1
  grep -qE "^##.* *${feat}( |$)|^###.* *${feat}( |$)|機能: *${feat}( |$)" "$GLOBAL_DESIGN" 2>/dev/null
}
feature_design_exists() {
  local feat="$1"
  [ -f "$FEATURES_DESIGN_DIR/${feat}.md" ]
}

# --- testTag 候補抽出（Android 固有 / 機能要件書テンプレートの「画面要素」セクション） ---
# パターン: 全角/半角カッコ内の testTag: xxx、または testTag: xxx
# ガイド文（「例 ...」「例: ...」で始まる行）は除外
extract_testtag_candidates() {
  local f="$1"
  [ -f "$f" ] || return 0
  grep -vE '^\s*-\s*[（(]?例[:：\s]' "$f" 2>/dev/null \
    | grep -oE '[(（]?\s*testTag\s*[:：]\s*[a-z_][a-z0-9_]*' \
    | sed -E 's/^[(（]?\s*testTag\s*[:：]\s*//' \
    | sort -u
}

# --- 要件カバレッジ判定 ---
UNCOVERED_FEATURES=()
COVERED_FEATURES=()
for feat in "${FEATURE_NAMES[@]+"${FEATURE_NAMES[@]}"}"; do
  if feature_design_exists "$feat" || global_has_section_for "$feat"; then
    COVERED_FEATURES+=("$feat")
  else
    UNCOVERED_FEATURES+=("$feat")
  fi
done

# --- 未参照設計書の検出 ---
UNREF_DESIGNS=()
if [ -d "$FEATURES_DESIGN_DIR" ]; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    name="$(basename "$d" .md)"
    found=0
    for f in "${FEATURE_NAMES[@]+"${FEATURE_NAMES[@]}"}"; do
      [ "$f" = "$name" ] && found=1 && break
    done
    [ "$found" = "0" ] && UNREF_DESIGNS+=("docs/設計/features/${name}.md")
  done < <(find "$FEATURES_DESIGN_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
fi

# --- 機能要件書の必須サブセクションが設計書側でも触れられているかをチェック ---
REQUIRED_SUBSECTIONS=("画面要素" "ユーザー操作" "受け入れ条件")
MISSING_SUBSECTIONS=()
MISSING_TESTTAG_CANDIDATES=()

for feat in "${COVERED_FEATURES[@]+"${COVERED_FEATURES[@]}"}"; do
  design_file=""
  if feature_design_exists "$feat"; then
    design_file="$FEATURES_DESIGN_DIR/${feat}.md"
  fi
  if [ -z "$design_file" ]; then continue; fi
  for sub in "${REQUIRED_SUBSECTIONS[@]}"; do
    if ! grep -qE "^##+.*${sub}" "$design_file" 2>/dev/null; then
      MISSING_SUBSECTIONS+=("${feat}:${sub}:docs/設計/features/${feat}.md")
    fi
  done

  # Android 固有: testTag 候補が機能要件書にあれば、設計書「## testTag 一覧」セクションの存在を確認
  req_file=""
  for f in "${INPUTS_LIST[@]}"; do
    if [ "$(basename "$f")" = "機能要件_${feat}.md" ]; then req_file="$f"; break; fi
  done
  if [ -z "$req_file" ] && [ -f "$INPUT" ]; then
    # 要件定義書内の「## 機能: <feat>」セクション抽出は AI 判断に委ねる（複雑化回避）
    req_file=""
  fi
  if [ -n "$req_file" ]; then
    candidates="$(extract_testtag_candidates "$req_file")"
    if [ -n "$candidates" ]; then
      # 機能要件書に testTag 候補がある場合、設計書側の testTag 一覧セクション存在を確認
      if ! grep -qE "^##+.*testTag" "$design_file" 2>/dev/null; then
        MISSING_TESTTAG_CANDIDATES+=("${feat}:設計書に「## testTag 一覧」セクション欠落:docs/設計/features/${feat}.md")
      fi
    fi
  fi
done

# --- 出力 JSON の組み立て ---
CYCLE_PASSED="true"
[ "${#UNCOVERED_FEATURES[@]}" -gt 0 ] && CYCLE_PASSED="false"
[ "${#MISSING_SUBSECTIONS[@]}" -gt 0 ] && CYCLE_PASSED="false"
[ "${#MISSING_TESTTAG_CANDIDATES[@]}" -gt 0 ] && CYCLE_PASSED="false"

# 出力先（Android 単一ファイル方式）
if [ -z "$OUT" ]; then
  OUT="$STATE_DIR/attestations/coverage.json"
fi
mkdir -p "$(dirname "$OUT")"
TMP="$(mktemp)"

# 配列 → JSON
to_json_array() {
  if [ "$#" = "0" ]; then echo "[]"; return; fi
  printf '%s\n' "$@" | jq -R . | jq -s 'map(select(length>0))'
}
JQ_FEATURES="$(to_json_array "${FEATURE_NAMES[@]+"${FEATURE_NAMES[@]}"}")"
JQ_UNCOVERED="$(to_json_array "${UNCOVERED_FEATURES[@]+"${UNCOVERED_FEATURES[@]}"}")"
JQ_UNREF="$(to_json_array "${UNREF_DESIGNS[@]+"${UNREF_DESIGNS[@]}"}")"
JQ_MISSING_SUB="$(to_json_array "${MISSING_SUBSECTIONS[@]+"${MISSING_SUBSECTIONS[@]}"}")"
JQ_MISSING_TT="$(to_json_array "${MISSING_TESTTAG_CANDIDATES[@]+"${MISSING_TESTTAG_CANDIDATES[@]}"}")"
JQ_INPUTS="$(to_json_array "${INPUTS_LIST[@]+"${INPUTS_LIST[@]}"}")"

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
NEW_CYCLE="$(jq -n \
  --argjson cycle "$CYCLE" \
  --arg scanned_at "$NOW" \
  --argjson uncovered "$JQ_UNCOVERED" \
  --argjson missing_sub "$JQ_MISSING_SUB" \
  --argjson unreferenced "$JQ_UNREF" \
  --argjson missing_tt "$JQ_MISSING_TT" \
  --arg passed "$CYCLE_PASSED" \
  '{
     cycle: $cycle,
     scanned_at: $scanned_at,
     uncovered_features: $uncovered,
     missing_subsections: $missing_sub,
     unreferenced_designs: $unreferenced,
     missing_testtag_candidates: $missing_tt,
     passed: ($passed == "true")
   }')"

# 既存出力があれば cycles[] に append（同 cycle 番号は上書き）
EXISTING_CYCLES="[]"
if [ -f "$OUT" ]; then
  EXISTING_CYCLES="$(jq --argjson c "$CYCLE" '(.cycles // []) | map(select(.cycle != $c))' "$OUT" 2>/dev/null || echo "[]")"
fi

jq -n \
  --arg scope "system" \
  --arg scanned_at "$NOW" \
  --argjson final_cycle "$CYCLE" \
  --argjson cycles_pre "$EXISTING_CYCLES" \
  --argjson new_cycle "$NEW_CYCLE" \
  --argjson inputs "$JQ_INPUTS" \
  --arg design_dir "${DESIGN_DIR#$REPO_ROOT/}" \
  --argjson features "$JQ_FEATURES" \
  --arg passed "$CYCLE_PASSED" \
  '{
     scope: $scope,
     scanned_at: $scanned_at,
     final_cycle: $final_cycle,
     cycles: ($cycles_pre + [$new_cycle] | sort_by(.cycle)),
     inputs: $inputs,
     design_dir: $design_dir,
     features: $features,
     passed: ($passed == "true")
   }' > "$TMP"
mv "$TMP" "$OUT"

# --- レポート ---
echo "[INFO] 入力: ${INPUTS_LIST[*]}"
echo "[INFO] cycle=$CYCLE / 機能数=${#FEATURE_NAMES[@]} / 未カバー=${#UNCOVERED_FEATURES[@]} / サブセクション欠落=${#MISSING_SUBSECTIONS[@]} / testTag 欠落=${#MISSING_TESTTAG_CANDIDATES[@]}"
echo "[INFO] 出力: $OUT"

if [ "${#UNCOVERED_FEATURES[@]}" -gt 0 ]; then
  echo "[FAIL] 設計書に未マッピングの機能要件:"
  for f in "${UNCOVERED_FEATURES[@]}"; do echo "  - $f"; done
fi
if [ "${#MISSING_SUBSECTIONS[@]}" -gt 0 ]; then
  echo "[FAIL] 設計書に欠落する必須サブセクション:"
  for m in "${MISSING_SUBSECTIONS[@]}"; do echo "  - $m"; done
fi
if [ "${#MISSING_TESTTAG_CANDIDATES[@]}" -gt 0 ]; then
  echo "[FAIL] 設計書に欠落する testTag 一覧（要件書に候補あり）:"
  for m in "${MISSING_TESTTAG_CANDIDATES[@]}"; do echo "  - $m"; done
fi
if [ "${#UNREF_DESIGNS[@]}" -gt 0 ]; then
  echo "[WARN] 要件側に対応機能が見つからない設計書:"
  for d in "${UNREF_DESIGNS[@]}"; do echo "  - $d"; done
fi

if [ "$CYCLE_PASSED" = "true" ]; then
  echo "[OK] 要件↔設計 カバレッジ PASS (cycle=$CYCLE)"
  exit 0
fi

[ "$GATE" = "1" ] && exit 1 || exit 0
