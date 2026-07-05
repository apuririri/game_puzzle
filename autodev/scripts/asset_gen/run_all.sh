#!/usr/bin/env bash
# 全アセット（画像 + 音声 + BGM + SE）を生成し、APK を再ビルドして配信差替えまで一括実行。
#
# 前提:
#   - ComfyUI (http://localhost:8188) 稼働中（animagine-xl-4.0 モデル）
#   - VoiceVox  (http://localhost:50021) 稼働中
#   - emulator-5554 起動済み or --no-deploy
#
# 使い方:
#   bash autodev/scripts/asset_gen/run_all.sh                # 既存ファイルはスキップ
#   bash autodev/scripts/asset_gen/run_all.sh --force        # 既存ファイルも再生成
#   bash autodev/scripts/asset_gen/run_all.sh --no-deploy    # APK 再ビルド・配信差替えはスキップ
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
cd "$REPO"

FORCE=""
DEPLOY=1
for a in "$@"; do
  case "$a" in
    --force) FORCE="--force" ;;
    --no-deploy) DEPLOY=0 ;;
    --help|-h) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "[FAIL] 不明なオプション: $a"; exit 2 ;;
  esac
done

echo "==> [1/3] BGM/SE 生成（numpy 合成）"
python3 "$HERE/generate_bgm_se.py" $FORCE
echo "==> [2/3] ボイス生成（VoiceVox）"
python3 "$HERE/generate_voices.py" $FORCE
echo "==> [3/3] 立ち絵生成（ComfyUI）"
python3 "$HERE/generate_images.py" $FORCE

echo "==> 件数:"
echo "  画像: $(find app/src/main/assets/image/character -name '*.webp' 2>/dev/null | wc -l) / 35"
echo "  ボイス: $(find app/src/main/assets/voice -name '*.ogg' 2>/dev/null | wc -l) / 35"
echo "  BGM: $(find app/src/main/assets/bgm -name '*.ogg' 2>/dev/null | wc -l) / 7"
echo "  SE: $(find app/src/main/assets/se -name '*.ogg' 2>/dev/null | wc -l) / 9"

if [ "$DEPLOY" = "1" ]; then
  echo "==> APK 再ビルド (release)"
  bash autodev/scripts/build.sh release
  APK="app/build/outputs/apk/release/app-release.apk"
  if [ -f "$APK" ]; then
    VER="$(grep -oE 'versionName = "[^"]+"' app/build.gradle.kts | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
    OUT="autodev/artifacts/PrismaLink-v${VER}-release.apk"
    cp -f "$APK" "$OUT"
    cp -f "$APK" "autodev/distribution/www/PrismaLink-v${VER}.apk"
    ln -sf "PrismaLink-v${VER}.apk" "autodev/distribution/www/latest.apk"
    echo "==> 配信差替え完了: autodev/distribution/www/PrismaLink-v${VER}.apk"
    echo "  サイズ: $(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT") bytes"
    echo "  SHA-256: $(sha256sum "$OUT" | cut -d' ' -f1)"
  fi
fi

echo "DONE"
