#!/usr/bin/env bash
# dev 環境ヘルスチェック（FR-5.3.2 / 修正方針 §3-4）。
# JDK/SDK → Gradle → デバイス（無ければエミュレータ起動）→ アプリ起動マーカー → Maestro を確認。
# fallback 禁止（FR-5.3.3）: fail は fail として扱う。
# 自分で起動したエミュレータは後続作業のため停止しない（boot コストが高いため）。
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
source "$SCRIPTS_DIR/_device.sh"

FAIL=0
ok()   { echo "  [OK]   $*"; }
ng()   { echo "  [FAIL] $*"; FAIL=1; }

echo "== AutoDev for Android healthcheck =="

# 1) 環境（JDK/SDK/AVD/Maestro/jq）
if "$SCRIPTS_DIR/check_android_setup.sh" >/dev/null 2>&1; then
  ok "Android 環境（check_android_setup.sh）"
else
  ng "Android 環境不備。詳細: autodev/scripts/check_android_setup.sh"
fi

# 2) Gradle 動作（設定ロードまで検証。初回は Gradle 本体DLで時間がかかる）
if "$SCRIPTS_DIR/run_gradle.sh" help -q >/dev/null 2>&1; then
  ok "Gradle（gradlew help）"
else
  ng "Gradle 実行不可（run_gradle.sh help のログを確認）"
fi

# 3) デバイス（無ければエミュレータを起動）
SERIAL="$(pick_device "")" || SERIAL=""
if [ -z "$SERIAL" ]; then
  echo "  [..]   デバイス未接続 → エミュレータ起動を試行"
  SERIAL="$("$SCRIPTS_DIR/start_emulator.sh" 2>/dev/null | tail -1)" || SERIAL=""
fi
if [ -n "$SERIAL" ] && wait_boot "$SERIAL" 10; then
  ok "デバイス ($SERIAL)"
else
  ng "デバイス/エミュレータが利用できません"
fi

# 4) アプリ起動確認（/healthz 200 相当: install → launch → APP_STARTED マーカー）
if [ -n "$SERIAL" ]; then
  APK="$(apk_path debug)"
  if [ ! -f "$APK" ]; then
    echo "  [..]   debug APK 不在 → ビルド（初回は時間がかかります）"
    "$SCRIPTS_DIR/build.sh" debug >/dev/null 2>&1 || true
  fi
  if [ -f "$APK" ]; then
    if "$SCRIPTS_DIR/install.sh" "$APK" "$SERIAL" >/dev/null 2>&1 \
       && "$SCRIPTS_DIR/run.sh" "$SERIAL" 2>&1 | grep -q "起動確認 OK"; then
      ok "アプリ起動（APP_STARTED マーカー）"
    else
      ng "アプリの install/起動確認に失敗（run.sh / logcat_error.sh で調査）"
    fi
  else
    ng "debug APK のビルドに失敗（run_gradle.sh のログを確認）"
  fi
fi

# 5) Maestro
if "$SCRIPTS_DIR/run_maestro.sh" --version >/dev/null 2>&1; then
  ok "Maestro CLI"
else
  ng "Maestro 実行不可（setup_maestro.sh）"
fi

echo "========================="
if [ "$FAIL" = "0" ]; then echo "healthcheck: PASS"; exit 0; else echo "healthcheck: FAIL"; exit 1; fi
