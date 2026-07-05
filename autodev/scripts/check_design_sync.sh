#!/usr/bin/env bash
# 設計書 staleness ゲート（FR-5.4.4 / 修正方針 §3-7。Kotlin ソースの静的解析ベース）。
#  - Room: app/.../data/local/entity/ の @Entity（tableName/クラス名）が docs/設計/data_model.md に記載されているか
#  - API : app/.../data/remote/ の Retrofit アノテーション（@GET/@POST 等のパス）が docs/設計/api.md に記載されているか
#  - 画面: app/.../ui/screen/ の画面ファイルが docs/設計/screen_flow.md または features/ に記載されているか
# 乖離があれば WARN を出し、--gate 指定時のみ fail(1)。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

GATE=0; [ "${1:-}" = "--gate" ] && GATE=1
API_MD="$REPO_ROOT/docs/設計/api.md"
DM_MD="$REPO_ROOT/docs/設計/data_model.md"
SF_MD="$REPO_ROOT/docs/設計/screen_flow.md"
FEAT_DIR="$REPO_ROOT/docs/設計/features"
DRIFT=0
SRC="$APP_DIR/src/main"

[ -d "$SRC" ] || { echo "[WARN] app/src/main 不在のため設計同期チェックをスキップ"; exit 0; }

# 1) Room Entity（tableName= 指定があればその名前、無ければクラス名）
while IFS= read -r f; do
  TBL="$(grep -oE 'tableName *= *"[^"]+"' "$f" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
  [ -z "$TBL" ] && TBL="$(grep -A3 '@Entity' "$f" | grep -oE 'class +[A-Za-z0-9_]+' | head -1 | awk '{print $2}')"
  [ -z "$TBL" ] && continue
  if [ -f "$DM_MD" ]; then
    grep -qiF "$TBL" "$DM_MD" || { echo "[WARN] data_model.md に未記載の Entity/テーブル: $TBL (${f#$REPO_ROOT/})"; DRIFT=1; }
  else
    echo "[WARN] docs/設計/data_model.md が存在しません。"; DRIFT=1; break
  fi
done < <(grep -rl '@Entity' "$SRC" 2>/dev/null || true)

# 2) Retrofit エンドポイント
while IFS= read -r line; do
  P="$(echo "$line" | sed -E 's/.*@(GET|POST|PUT|DELETE|PATCH)\("([^"]*)"\).*/\2/')"
  [ -z "$P" ] && continue
  if [ -f "$API_MD" ]; then
    grep -qF "$P" "$API_MD" || { echo "[WARN] api.md に未記載の API パス: $P"; DRIFT=1; }
  else
    echo "[WARN] docs/設計/api.md が存在しません。"; DRIFT=1; break
  fi
done < <(grep -rhoE '@(GET|POST|PUT|DELETE|PATCH)\("[^"]*"\)' "$SRC" 2>/dev/null | sort -u || true)

# 3) 画面（ui/screen/ の *Screen.kt）
while IFS= read -r f; do
  NAME="$(basename "$f" .kt)"
  HIT=0
  [ -f "$SF_MD" ] && grep -qF "$NAME" "$SF_MD" && HIT=1
  [ "$HIT" = "0" ] && [ -d "$FEAT_DIR" ] && grep -rqF "$NAME" "$FEAT_DIR" 2>/dev/null && HIT=1
  [ "$HIT" = "0" ] && { echo "[WARN] 設計書（screen_flow.md / features/）に未記載の画面: $NAME"; DRIFT=1; }
done < <(find "$SRC" -path '*/ui/screen/*' -name '*Screen.kt' 2>/dev/null || true)

if [ "$DRIFT" = "0" ]; then echo "[OK] 設計書と実装の乖離は検出されませんでした。"; exit 0; fi
echo "[INFO] 設計書の同期が必要です（autodev-design-sync skill）。"
[ "$GATE" = "1" ] && exit 1 || exit 0
