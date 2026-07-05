#!/usr/bin/env bash
# 蓄積データの洗い替え（FR: 本番運用フェイズ補足 / データライフサイクル章）。
# 使い方:
#   cleanup.sh                # dry-run（対象を提示するだけ。変更しない）
#   cleanup.sh --apply        # retention.yaml に従いアーカイブ→prune
#   cleanup.sh --full-reset --apply   # 運用履歴をクリーンスレート化（コード/設計/台帳/進行中は保持）
# 安全策: app/ maestro/ docs/設計/ CHANGELOG / docs/変更履歴 / personas は絶対に触らない。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

RET="$AUTODEV_DIR/config/retention.yaml"
APPLY=0; FULL=0
for a in "$@"; do case "$a" in --apply) APPLY=1;; --full-reset) FULL=1;; esac; done

conf() { conf_get "$RET" "$1" "$2"; }

EV_KEEP="$(conf evidence.keep_days 30)"
LOG_KEEP="$(conf logs.keep_days 30)"
HIST_KEEP="$(conf history.keep_items 30)"
ART_KEEP="$(conf artifacts.keep_items 5)"

ARCH_DIR="$AUTODEV_DIR/archive"; mkdir -p "$ARCH_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
STAGE="$(mktemp -d "${ARCH_DIR}/.stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

note() { echo "  - $*"; }
total=0
stage_add() { # stage_add <path>（アーカイブ用にコピー退避）
  local p="$1"; [ -e "$p" ] || return 0
  local rel="${p#$REPO_ROOT/}"; mkdir -p "$STAGE/$(dirname "$rel")"; cp -a "$p" "$STAGE/$rel"; total=$((total+1))
}

echo "==== 洗い替え（$([ "$FULL" = 1 ] && echo full-reset || echo retention), apply=$APPLY）===="
echo "[!] CHANGELOG.md / docs/変更履歴.md に要約を追記してから実行してください（監査性のため）。"

declare -a CANDIDATES=()

if [ "$FULL" = "1" ]; then
  echo "[full-reset] 運用履歴を一掃（コード/設計/台帳/personas/進行中 system.json は保持）"
  while IFS= read -r f; do CANDIDATES+=("$f"); done < <(
    find "$EVIDENCE_DIR" "$AUTODEV_DIR/logs" "$STATE_DIR/history" "$STATE_DIR/iterations" \
         "$STATE_DIR/persona_tests" -type f ! -name '.gitkeep' 2>/dev/null
    find "$AUTODEV_DIR/inputs/修正対応" -type f -name '修正_*.md' 2>/dev/null
  )
else
  # 案7: critical_evidence.archived_dir 配下は prune 対象から除外する。
  ARCH_REL="$(conf critical_evidence.archived_dir autodev/evidence/_archived)"
  ARCH_ABS="$REPO_ROOT/$ARCH_REL"
  echo "[retention] evidence>${EV_KEEP}日 / logs>${LOG_KEEP}日 / history>${HIST_KEEP}件（_archived/ 除外）"
  while IFS= read -r f; do CANDIDATES+=("$f"); done < <(
    find "$EVIDENCE_DIR" -path "$ARCH_ABS" -prune -o -type f ! -name '.gitkeep' -mtime +"$EV_KEEP" -print 2>/dev/null
    find "$AUTODEV_DIR/logs" -type f ! -name '.gitkeep' -mtime +"$LOG_KEEP" 2>/dev/null
    ls -t "$STATE_DIR/history"/*.md 2>/dev/null | tail -n +"$((HIST_KEEP+1))"
    ls -t "$AUTODEV_DIR/artifacts"/*.apk 2>/dev/null | tail -n +"$((ART_KEEP+1))"
  )
fi

if [ "${#CANDIDATES[@]}" -eq 0 ]; then echo "[OK] 洗い替え対象なし。"; exit 0; fi
echo "対象 ${#CANDIDATES[@]} 件:"; for f in "${CANDIDATES[@]}"; do note "${f#$REPO_ROOT/}"; done | head -40
[ "${#CANDIDATES[@]}" -gt 40 ] && echo "  ...(他 $(( ${#CANDIDATES[@]} - 40 )) 件)"

if [ "$APPLY" != "1" ]; then
  echo; echo "[dry-run] 変更していません。--apply で「アーカイブ→削除」を実行します。"
  exit 0
fi

# アーカイブ → 削除
for f in "${CANDIDATES[@]}"; do stage_add "$f"; done
ARCHIVE="$ARCH_DIR/cleanup_${TS}.tar.gz"
( cd "$STAGE" && tar czf "$ARCHIVE" . ) && echo "[archive] $total 件を $ARCHIVE に退避"
for f in "${CANDIDATES[@]}"; do rm -f "$f"; done
echo "[prune] 削除完了。"
"$SCRIPTS_DIR/update_progress_md.sh" >/dev/null 2>&1 || true
echo "[OK] 洗い替え完了。アーカイブ: ${ARCHIVE#$REPO_ROOT/}"
