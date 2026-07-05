#!/usr/bin/env bash
# アーティファクト解決（Android 版 / 修正方針 §3-6）。使い方: resolve_artifact.sh <source> <target>
# 標準出力に "STRATEGY <rebuild|promote>" "GITSHA <sha>" "PREV_APK <path>" を返す。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"
source "$SCRIPTS_DIR/_deploy_lib.sh"

SRC="${1:-}"; TGT="${2:-}"
STRATEGY="$(dconf "environments.$TGT.build_strategy" "$(dconf defaults.build_strategy rebuild)")"

SHA=""
if command -v git >/dev/null 2>&1; then
  SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

# promote: autodev/artifacts/ の最新署名済み APK を再利用
PREV_APK="$(ls -t "$ARTIFACTS_DIR"/*.apk 2>/dev/null | head -1 || true)"

echo "STRATEGY $STRATEGY"
echo "GITSHA ${SHA:-unknown}"
echo "PREV_APK ${PREV_APK:-}"
