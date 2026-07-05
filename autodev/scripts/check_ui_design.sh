#!/usr/bin/env bash
# S11 UP3 デザイン評価軸の欠落検出（FR-5.18.4）。
# autodev/state/ui_polish/<screen>.json::issues[] が ui_polish.yaml::criteria[].id の全項目を
# 含んでいることを機械検証する。AI が評価を省略した画面・観点を fail で停止させる。
#
# 使い方:
#   check_ui_design.sh                  # 全画面を検査
#   check_ui_design.sh <screen>         # 指定画面のみ
#   check_ui_design.sh --warn           # exit 0
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --warn) MODE="warn"; shift ;;
    --strict) MODE="strict"; shift ;;
    *) TARGET="$1"; shift ;;
  esac
done

CONF="$AUTODEV_DIR/config/ui_polish.yaml"
INVENTORY="$REPO_ROOT/$(conf_get "$CONF" inventory_path "autodev/state/ui_polish/inventory.json")"
UI_STATE_DIR="$STATE_DIR/ui_polish"

command -v jq >/dev/null 2>&1 || { echo "[FAIL] jq が必要です"; exit 2; }
[ -f "$INVENTORY" ] || { echo "[FAIL] inventory.json が未生成（先に list_screens.sh）"; exit 1; }

# criteria id の一覧を yaml から抽出（PyYAML 無しでも動くよう簡易: id を grep）。
PY="$(detect_python || echo "")"
if [ -n "$PY" ]; then
  CRITERIA_IDS="$("$PY" - <<PYEOF
import re,sys
with open("$CONF","r",encoding="utf-8") as f: t=f.read()
ids=re.findall(r'-\s*id:\s*([A-Za-z0-9_]+)', t)
print("\n".join(ids))
PYEOF
)"
else
  CRITERIA_IDS="$(grep -E '^\s*-\s*id:' "$CONF" | sed -E 's/^\s*-\s*id:\s*//')"
fi
[ -z "$CRITERIA_IDS" ] && CRITERIA_IDS=$'visibility\nlayout\nconsistency\nusability\ndynamic_state\nmaterial3\nspacing\na11y'

FAIL=0
check_screen() {  # check_screen <screen_id> <route>
  local sid="$1" route="$2"
  local f="$UI_STATE_DIR/${sid}.json"
  if [ ! -f "$f" ]; then
    echo "[FAIL] $route (screen_id=$sid): $UI_STATE_DIR/${sid}.json が不在（UP3 未実施）"
    FAIL=1
    return
  fi
  local miss=""
  while IFS= read -r cid; do
    [ -z "$cid" ] && continue
    if ! jq -e --arg c "$cid" '[.issues[]? | select(.criterion==$c)] | length > 0' "$f" >/dev/null 2>&1; then
      miss="$miss $cid"
    fi
  done <<< "$CRITERIA_IDS"
  if [ -n "$miss" ]; then
    echo "[FAIL] $route (screen_id=$sid): 評価軸の欠落:$miss"
    FAIL=1
  else
    echo "[OK] $route (screen_id=$sid): 全評価軸あり"
  fi
}

if [ -n "$TARGET" ]; then
  # TARGET は route でも screen_id でも可。inventory から解決
  sid="$(jq -r --arg t "$TARGET" '.screens[] | select(.route==$t or .screen_id==$t) | .screen_id' "$INVENTORY" | head -1)"
  route="$(jq -r --arg t "$TARGET" '.screens[] | select(.route==$t or .screen_id==$t) | .route' "$INVENTORY" | head -1)"
  [ -z "$sid" ] && { echo "[FAIL] inventory に \"$TARGET\" がありません"; exit 1; }
  check_screen "$sid" "$route"
else
  while IFS=$'\t' read -r sid route; do
    [ -z "$sid" ] && continue
    check_screen "$sid" "$route"
  done < <(jq -r '.screens[]? | "\(.screen_id // (.route|gsub("/";"_")|gsub("[{}?]";"_")))\t\(.route)"' "$INVENTORY")
fi

if [ "$FAIL" = "1" ]; then
  echo "[FAIL] check_ui_design: 評価軸の欠落あり（FR-5.18.4 違反）"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] check_ui_design: 全画面で評価軸完備"
exit 0
