#!/usr/bin/env bash
# Maestro CLI の無人導入（修正方針 §6-7）。冪等。
# 方式: GitHub Releases の maestro.zip を直接取得して $MAESTRO_HOME に展開（決定的・版固定可）。
#       失敗時のみ公式インストーラ（get.maestro.mobile.dev）にフォールバック。
# 版指定: android_env.yaml::maestro.version（例 "1.39.13"。空なら latest）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

VER="$(aconf maestro.version "")"
CLI="$MAESTRO_HOME/bin/maestro"
LOG="$(log_dir)/setup_maestro_$(date +%H%M%S).log"

verify() {  # 導入確認（maestro は JVM アプリのため java が必要）
  local cli="$1"
  [ -x "$cli" ] || return 1
  "$cli" --version >>"$LOG" 2>&1 || return 1
  return 0
}

# 既に導入済みなら確認だけして終了（版指定があれば一致確認）
if [ -x "$CLI" ]; then
  CUR="$("$CLI" --version 2>/dev/null | head -1 || echo unknown)"
  if [ -z "$VER" ] || echo "$CUR" | grep -q "$VER"; then
    echo "  [OK]   Maestro 導入済み ($CUR)"
    exit 0
  fi
  echo "  [..]   Maestro 版不一致（現: $CUR / 指定: $VER）→ 再導入"
fi

# 前提: java（maestro は JVM アプリ）
if [ -z "${JAVA_HOME:-}" ] && ! command -v java >/dev/null 2>&1; then
  echo "  [FAIL] java が見つかりません（setup_android_env.sh を先に実行してください）"
  exit 1
fi

# ---- 方式1: GitHub Releases から zip を直接取得（推奨・決定的） ----
if [ -n "$VER" ]; then
  URL="https://github.com/mobile-dev-inc/maestro/releases/download/cli-${VER}/maestro.zip"
else
  URL="https://github.com/mobile-dev-inc/maestro/releases/latest/download/maestro.zip"
fi
echo "  [..]   Maestro をダウンロード（$URL）..."
TMP="$(mktemp -d)"
INSTALLED=0
if curl -fSL --retry 3 --retry-delay 3 -o "$TMP/maestro.zip" "$URL" >>"$LOG" 2>&1; then
  if unzip -q -o "$TMP/maestro.zip" -d "$TMP/x" >>"$LOG" 2>&1; then
    # zip 内レイアウトに依存せず bin/maestro を持つディレクトリを探す
    BIN="$(find "$TMP/x" -type f -name maestro -path '*/bin/*' | head -1)"
    if [ -n "$BIN" ]; then
      SRC_DIR="$(cd "$(dirname "$BIN")/.." && pwd)"
      rm -rf "$MAESTRO_HOME"
      mkdir -p "$(dirname "$MAESTRO_HOME")"
      cp -a "$SRC_DIR" "$MAESTRO_HOME"
      chmod +x "$MAESTRO_HOME/bin/maestro" 2>/dev/null || true
      verify "$MAESTRO_HOME/bin/maestro" && INSTALLED=1
    fi
  fi
fi

# ---- 方式2: 公式インストーラへフォールバック ----
if [ "$INSTALLED" != "1" ]; then
  echo "  [..]   直接取得に失敗 → 公式インストーラにフォールバック（ログ: ${LOG#$REPO_ROOT/}）"
  [ -n "$VER" ] && export MAESTRO_VERSION="$VER"
  curl -fsSL --retry 3 "https://get.maestro.mobile.dev" 2>>"$LOG" | bash >>"$LOG" 2>&1 || true
  CLI2="$MAESTRO_HOME/bin/maestro"
  [ -x "$CLI2" ] || CLI2="$(command -v maestro || true)"
  if [ -n "$CLI2" ] && verify "$CLI2"; then INSTALLED=1; fi
fi

rm -rf "$TMP"
if [ "$INSTALLED" = "1" ]; then
  echo "  [OK]   Maestro 導入完了 ($("$MAESTRO_HOME/bin/maestro" --version 2>/dev/null | head -1 || echo OK))"
  exit 0
fi
echo "  [FAIL] Maestro 導入失敗。ログを確認してください: $LOG"
echo "         直近のログ:"
tail -15 "$LOG" 2>/dev/null | sed 's/^/         /'
echo "         手動導入する場合: https://docs.maestro.dev/getting-started/installing-maestro"
exit 1
