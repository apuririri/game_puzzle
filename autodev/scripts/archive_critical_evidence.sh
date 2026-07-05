#!/usr/bin/env bash
# attestation 完了時に evidence.screenshots を _archived/ へ永続化（案7）。
# 使い方:
#   archive_critical_evidence.sh <attestation_path>   # 個別
#   archive_critical_evidence.sh --all                # 全 attestation を再アーカイブ
# retention.yaml::critical_evidence.enabled が true のときのみ実行する。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq が必要です。" >&2; exit 2; }

RET="$AUTODEV_DIR/config/retention.yaml"
conf() { conf_get "$RET" "$1" "$2"; }
ENABLED="$(conf critical_evidence.enabled true)"
if [ "$ENABLED" != "true" ]; then
  echo "[SKIP] critical_evidence.enabled=false（retention.yaml）。"
  exit 0
fi

ARCH_REL="$(conf critical_evidence.archived_dir autodev/evidence/_archived)"
ARCH_BASE="$REPO_ROOT/$ARCH_REL"
mkdir -p "$ARCH_BASE"

archive_one() {
  local at="$1"
  [ -f "$at" ] || { echo "[SKIP] $at 不在"; return 0; }
  local target ev src dst
  target="$(jq -r '.target // ""' "$at")"
  [ -z "$target" ] && { echo "[SKIP] $at: target 空"; return 0; }
  local copied=0
  for key in screenshots logcat; do
    ev="$(jq -r ".evidence.$key // \"\"" "$at")"
    [ -z "$ev" ] && continue
    src="$REPO_ROOT/$ev"
    if [ ! -d "$src" ]; then
      echo "[WARN] $target: $ev 不在"
      continue
    fi
    dst="$ARCH_BASE/$target/$key"
    mkdir -p "$dst"
    # 内容コピー（既存上書き）。dot ファイルも含めるため /. 構文。
    cp -a "$src"/. "$dst"/
    echo "[OK]   $target: $ev → $ARCH_REL/$target/$key/"
    copied=1
  done
  [ "$copied" = "0" ] && echo "[SKIP] $target: evidence.screenshots / evidence.logcat 未定義"
}

case "${1:-}" in
  --all)
    for at in "$STATE_DIR"/attestations/*.json; do
      [ -f "$at" ] || continue
      archive_one "$at"
    done
    ;;
  "")
    echo "Usage: $0 <attestation.json> | --all" >&2
    exit 1
    ;;
  *)
    archive_one "$1"
    ;;
esac
exit 0
