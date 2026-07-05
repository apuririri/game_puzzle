#!/usr/bin/env bash
# デッド資産検出ゲート（FR-5.8.5 / 修正方針 §3-8。Android lint + 簡易参照解析）。
# 検出時 WARN。--gate 指定時のみ fail(1)。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

GATE=0; [ "${1:-}" = "--gate" ] && GATE=1
DEAD=0

# 1) Android lint の UnusedResources（lint 実行は重いので結果 XML が新しければ再利用）
LINT_XML="$APP_DIR/build/reports/lint-results-debug.xml"
NEED_LINT=1
if [ -f "$LINT_XML" ]; then
  # 直近1時間以内のレポートは再利用
  if [ -n "$(find "$LINT_XML" -mmin -60 2>/dev/null)" ]; then NEED_LINT=0; fi
fi
if [ "$NEED_LINT" = "1" ]; then
  "$SCRIPTS_DIR/run_gradle.sh" :app:lintDebug >/dev/null 2>&1 || echo "[WARN] lint 実行に失敗（スキップして簡易解析のみ）"
fi
if [ -f "$LINT_XML" ]; then
  UNUSED="$(grep -c 'id="UnusedResources"' "$LINT_XML" 2>/dev/null || true)"
  UNUSED="${UNUSED:-0}"
  if [ "${UNUSED:-0}" -gt 0 ]; then
    echo "[WARN] lint: 未使用リソース $UNUSED 件（$LINT_XML）"
    grep -B1 'id="UnusedResources"' "$LINT_XML" | grep -oE 'message="[^"]+"' | head -10 | sed 's/^/  - /'
    DEAD=1
  fi
fi

# 2) ui/component/ 配下でどこからも参照されない Composable ファイル（簡易）
SRC="$APP_DIR/src/main"
if [ -d "$SRC" ]; then
  while IFS= read -r f; do
    base="$(basename "$f" .kt)"
    refs="$(grep -rlE "\b$base\b" "$APP_DIR/src" 2>/dev/null | grep -v "$f" | wc -l | tr -d ' ')"
    [ "${refs:-0}" -eq 0 ] && { echo "[WARN] 未参照の可能性があるコンポーネント: ${f#$REPO_ROOT/}"; DEAD=1; }
  done < <(find "$SRC" -path '*/ui/component/*' -name '*.kt' 2>/dev/null || true)
fi

if [ "$DEAD" = "0" ]; then echo "[OK] デッド資産は検出されませんでした。"; exit 0; fi
[ "$GATE" = "1" ] && exit 1 || exit 0
