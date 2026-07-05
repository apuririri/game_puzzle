#!/usr/bin/env bash
# S14 RG1 依存関係の最小整合確認（FR-5.19.2）。
# - Gradle dependencies に SNAPSHOT / -alpha / -beta / -rc が含まれないこと
# - version catalog（gradle/libs.versions.toml）が存在し、build.gradle.kts が直接 version 文字列を持たないこと
#
# 使い方:
#   check_dependencies.sh         # 検査
#   check_dependencies.sh --warn  # exit 0
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
[ "${1:-}" = "--warn" ] && MODE="warn"

FAIL=0

# 1) SNAPSHOT / 不安定版の検出
SCAN_TARGETS=()
[ -f "$APP_DIR/build.gradle.kts" ] && SCAN_TARGETS+=("$APP_DIR/build.gradle.kts")
[ -f "$REPO_ROOT/gradle/libs.versions.toml" ] && SCAN_TARGETS+=("$REPO_ROOT/gradle/libs.versions.toml")
[ -f "$REPO_ROOT/build.gradle.kts" ] && SCAN_TARGETS+=("$REPO_ROOT/build.gradle.kts")
[ -f "$REPO_ROOT/settings.gradle.kts" ] && SCAN_TARGETS+=("$REPO_ROOT/settings.gradle.kts")

for f in "${SCAN_TARGETS[@]}"; do
  HITS="$(grep -nEi '(SNAPSHOT|-alpha[0-9]|-beta[0-9]|-rc[0-9])' "$f" 2>/dev/null || true)"
  if [ -n "$HITS" ]; then
    echo "[FAIL] ${f#$REPO_ROOT/}: SNAPSHOT / 不安定版の検出"
    echo "$HITS" | head -20 | sed 's/^/  /'
    FAIL=1
  fi
done

# 2) version catalog 存在
if [ ! -f "$REPO_ROOT/gradle/libs.versions.toml" ]; then
  echo "[WARN] gradle/libs.versions.toml が不在（Version Catalog 推奨 / FR-5.19.2）"
fi

# 3) build.gradle.kts に直書き version 文字列がないか（簡易検出）
if [ -f "$APP_DIR/build.gradle.kts" ]; then
  DIRECT_VER="$(grep -nE '"[a-z0-9_.-]+:[a-z0-9_.-]+:[0-9]+\.[0-9]+' "$APP_DIR/build.gradle.kts" \
                | grep -v 'libs\.' || true)"
  if [ -n "$DIRECT_VER" ]; then
    echo "[WARN] app/build.gradle.kts に直書き dependency version あり（libs.versions.toml へ集約推奨）:"
    echo "$DIRECT_VER" | head -20 | sed 's/^/  /'
  fi
fi

if [ "$FAIL" = "1" ]; then
  echo "[FAIL] check_dependencies: NG"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] check_dependencies: PASS"
exit 0
