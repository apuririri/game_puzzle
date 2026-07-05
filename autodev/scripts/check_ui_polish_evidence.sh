#!/usr/bin/env bash
# S11 UP7 全画面 before/after スクショ揃いの機械検証（FR-5.18.7 / FR-5.18.9）。
# inventory.json に列挙された全 Navigation ルートに before.png と after.png が
# 存在することを確認する。動的状態は dynamic_state_optional 登録時のみ省略可。
#
# 使い方:
#   check_ui_polish_evidence.sh         # 全画面検査。1件でも欠ければ exit 1
#   check_ui_polish_evidence.sh --warn  # exit 0 で続行
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
[ "${1:-}" = "--warn" ] && MODE="warn"

CONF="$AUTODEV_DIR/config/ui_polish.yaml"
INVENTORY="$REPO_ROOT/$(conf_get "$CONF" inventory_path "autodev/state/ui_polish/inventory.json")"
EVIDENCE_OUT="$REPO_ROOT/$(conf_get "$CONF" evidence_dir "autodev/evidence/ui_polish")"

command -v jq >/dev/null 2>&1 || { echo "[FAIL] jq が必要です"; exit 2; }
[ -f "$INVENTORY" ] || { echo "[FAIL] inventory.json が未生成"; exit 1; }

DYN_STATES="$(conf_list "$CONF" dynamic_states)"
[ -z "$DYN_STATES" ] && DYN_STATES=$'loading\nempty\nerror'
OPT_SCREENS="$(conf_list "$CONF" dynamic_state_optional)"

is_optional() {  # is_optional <screen_id_or_route>
  local r="$1"
  while IFS= read -r o; do
    [ -z "$o" ] && continue
    [ "$o" = "$r" ] && return 0
  done <<< "$OPT_SCREENS"
  return 1
}

FAIL=0
while IFS=$'\t' read -r sid route; do
  [ -z "$sid" ] && continue
  d="$EVIDENCE_OUT/$sid"
  label="$route (screen_id=$sid)"
  # 必須: before.png / after.png
  if [ ! -f "$d/before.png" ]; then echo "[FAIL] $label: before.png 不在 (${d#$REPO_ROOT/})"; FAIL=1; fi
  if [ ! -f "$d/after.png" ];  then echo "[FAIL] $label: after.png 不在 (${d#$REPO_ROOT/})";  FAIL=1; fi
  # diff.md（UP6 出力物）
  if [ ! -f "$d/diff.md" ]; then echo "[FAIL] $label: diff.md 不在"; FAIL=1; fi
  # 動的状態: dynamic_state_optional に登録された screen_id/route は省略可
  if is_optional "$sid" || is_optional "$route"; then
    echo "[INFO] $label: dynamic_state_optional のため動的状態スクショ省略可"
  else
    # 動的状態の maestro flow が存在する場合のみ必須化（flow が無ければ最初から評価対象外）
    for st in $DYN_STATES; do
      f_flow="$MAESTRO_DIR/_polish/_state_${sid}_${st}.yaml"
      if [ -f "$f_flow" ]; then
        if [ ! -f "$d/before_${st}.png" ]; then echo "[FAIL] $label: before_${st}.png 不在"; FAIL=1; fi
        if [ ! -f "$d/after_${st}.png" ];  then echo "[FAIL] $label: after_${st}.png 不在";  FAIL=1; fi
      fi
    done
  fi
done < <(jq -r '.screens[]? | "\(.screen_id // (.route|gsub("/";"_")|gsub("[{}?]";"_")))\t\(.route)"' "$INVENTORY")

if [ "$FAIL" = "1" ]; then
  echo "[FAIL] check_ui_polish_evidence: スクショ揃い NG（FR-5.18.9 違反）"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] check_ui_polish_evidence: 全画面 before/after 揃い"
exit 0
