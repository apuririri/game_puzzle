#!/usr/bin/env bash
# S14 RG1 AndroidManifest リリース時要件の検証（FR-5.19.2）。
# debuggable=false / usesCleartextTraffic 方針 / allowBackup 方針 / network_security_config / 過剰権限 /
# exported 明示 を機械検証する。
#
# 使い方:
#   check_manifest_release.sh         # 検査。NG で exit 1
#   check_manifest_release.sh --warn  # exit 0
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="strict"
[ "${1:-}" = "--warn" ] && MODE="warn"

CONF="$AUTODEV_DIR/config/release.yaml"
MANIFEST="$APP_DIR/src/main/AndroidManifest.xml"

[ -f "$MANIFEST" ] || { echo "[FAIL] AndroidManifest.xml が不在: $MANIFEST"; exit 1; }

FAIL=0

# 1) debuggable: false（または属性なし）
if grep -qE 'android:debuggable\s*=\s*"true"' "$MANIFEST"; then
  echo "[FAIL] AndroidManifest.xml に android:debuggable=\"true\" が残っています（リリースビルドでは false）"
  FAIL=1
fi

# 2) usesCleartextTraffic: true は network_security_config 必須
if grep -qE 'android:usesCleartextTraffic\s*=\s*"true"' "$MANIFEST"; then
  if ! grep -qE 'android:networkSecurityConfig\s*=\s*"@xml/[^"]+"' "$MANIFEST"; then
    echo "[FAIL] usesCleartextTraffic=true なのに networkSecurityConfig 未設定（中間者攻撃リスク）"
    FAIL=1
  fi
fi

# 3) allowBackup: true は方針を文書化していること（warning）
if grep -qE 'android:allowBackup\s*=\s*"true"' "$MANIFEST"; then
  echo "[WARN] allowBackup=true: バックアップに含まれる情報の方針を docs/設計/全体設計書.md::§セキュリティ に明記してください"
fi

# 4) 過剰権限の検出（release.yaml の allowed_permissions に列挙されたものだけ許容）
ALLOWED="$(conf_list "$CONF" allowed_permissions)"
DECLARED="$(grep -oE 'android.permission\.[A-Z_]+' "$MANIFEST" | sort -u)"
EXTRA="$(comm -23 <(echo "$DECLARED") <(echo "$ALLOWED" | sort -u) 2>/dev/null || true)"
if [ -n "$EXTRA" ]; then
  echo "[FAIL] 許可されていない権限が宣言されています（release.yaml::allowed_permissions に追加してください）:"
  echo "$EXTRA" | sed 's/^/  - /'
  FAIL=1
fi

# 5) exported 明示（Android 12+ では activity/receiver/service/provider に android:exported 必須）
UNSPEC="$(grep -E '<(activity|receiver|service|provider)\b' "$MANIFEST" | grep -v 'android:exported=' || true)"
if [ -n "$UNSPEC" ]; then
  echo "[FAIL] android:exported を明示していないコンポーネントがあります（Android 12+ 必須）:"
  echo "$UNSPEC" | sed 's/^/  /'
  FAIL=1
fi

if [ "$FAIL" = "1" ]; then
  echo "[FAIL] check_manifest_release: NG"
  [ "$MODE" = "warn" ] && exit 0 || exit 1
fi
echo "[OK] check_manifest_release: PASS"
exit 0
