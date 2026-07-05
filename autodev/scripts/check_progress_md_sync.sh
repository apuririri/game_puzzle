#!/usr/bin/env bash
# 進捗.md と state の同期確認（FR-5.6.7）。
# state の最新 JSON 更新時刻より進捗.md が古ければ fail（乖離検出）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

if [ ! -f "$PROGRESS_MD" ]; then
  echo "[FAIL] 開発進捗状況.md が存在しません。update_progress_md.sh を実行してください。"
  exit 1
fi

# state 配下の最新 mtime（空 find→xargs 事故を避けるためループで判定。-printf 非依存で移植性確保）
# heartbeat.json は揮発（.gitignore 対象）なので比較対象から除外。
LATEST_STATE=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ -z "$LATEST_STATE" ] || [ "$f" -nt "$LATEST_STATE" ]; then LATEST_STATE="$f"; fi
done < <(find "$STATE_DIR" -name '*.json' -type f -not -name 'heartbeat.json' 2>/dev/null)

if [ -z "$LATEST_STATE" ]; then
  echo "[OK] state JSON はまだ無し（雛形 / 初期状態）。進捗.md 存在のみ確認。"
  exit 0
fi

if [ "$LATEST_STATE" -nt "$PROGRESS_MD" ]; then
  echo "[FAIL] state ($LATEST_STATE) が進捗.md より新しい。update_progress_md.sh で同期してください。"
  exit 1
fi

echo "[OK] 進捗.md は state と同期しています。"
exit 0
