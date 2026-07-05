#!/usr/bin/env bash
# autodev/skills/ → .claude/skills/ への同期（FR-5.16.1 / FR-5.16.7）。
# 既定はコピー方式（クロスプラットフォーム安全 / Windows Git Bash 既定）。
#   --symlink : シンボリックリンク方式（Linux/macOS で権限がある場合）
#   --check   : 同期ずれを検出（差分があれば fail。pre-push 用）
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SRC="$AUTODEV_DIR/skills"
DST="$REPO_ROOT/.claude/skills"
MODE="copy"
[ "${1:-}" = "--symlink" ] && MODE="symlink"
[ "${1:-}" = "--check" ] && MODE="check"

mkdir -p "$DST"

if [ "$MODE" = "check" ]; then
  RC=0
  for d in "$SRC"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    if [ ! -f "$DST/$name/SKILL.md" ]; then echo "[FAIL] 未同期: $name"; RC=1; continue; fi
    if ! diff -q "$d/SKILL.md" "$DST/$name/SKILL.md" >/dev/null 2>&1; then
      echo "[FAIL] 内容差分: $name"; RC=1
    fi
  done
  [ "$RC" = "0" ] && echo "[OK] .claude/skills は autodev/skills と同期済み" || echo "[FAIL] sync_claude_dir.sh を実行してください"
  exit "$RC"
fi

for d in "$SRC"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  if [ "$MODE" = "symlink" ]; then
    rm -rf "$DST/$name"
    ln -s "../../autodev/skills/$name" "$DST/$name" 2>/dev/null \
      || { log_warn "symlink 失敗。コピーにフォールバック: $name"; mkdir -p "$DST/$name"; cp "$d/SKILL.md" "$DST/$name/SKILL.md"; }
  else
    mkdir -p "$DST/$name"
    cp "$d/SKILL.md" "$DST/$name/SKILL.md"
  fi
done

log_info ".claude/skills へ同期完了（mode=$MODE）"
