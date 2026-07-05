---
name: autodev-gradle-env
description: Android アプリのビルド・テスト・インストール・ADB 操作を行う直前に発動。素の gradle/gradlew/adb/emulator/sdkmanager/maestro を直接実行せず、環境解決とログ記録を備えた autodev/scripts/ のラッパー経由で実行するための標準手順。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-gradle-env skill

## 適用条件

- app/ のビルド・テスト・lint・インストール・起動・スクショ・logcat 取得・エミュレータ操作のすべての場面。

## 標準手順

1. **環境確認**: 不安があれば `autodev/scripts/check_android_setup.sh`。不足は `bash setup.sh`（全自動導入・冪等）。
2. **必ずラッパー/高レベルスクリプト経由で実行**:

   | 目的 | コマンド |
   |---|---|
   | Gradle タスク | `autodev/scripts/run_gradle.sh <task> <args...>` |
   | ビルド | `autodev/scripts/build.sh [debug\|release]` |
   | インストール / 起動 | `autodev/scripts/install.sh` / `run.sh` / `build_install_run.sh` |
   | 単体テスト | `autodev/scripts/test_unit.sh [--tests <pattern>]` |
   | UI テスト | `autodev/scripts/test_ui.sh [テストクラスFQCN]` |
   | E2E | `autodev/scripts/test_maestro.sh <flow.yaml> [対象名]` |
   | スクショ / ログ | `screenshot.sh` / `logcat.sh` / `logcat_error.sh` / `clean_logs.sh` |
   | adb 任意操作 | `autodev/scripts/run_adb.sh <args...>` |
   | エミュレータ | `start_emulator.sh` / `stop_emulator.sh` |

3. **禁止**: 素の `gradle` / `./gradlew` / `adb` / `emulator` / `avdmanager` / `sdkmanager` / `maestro` / `apksigner` を直接呼ばない。PreToolUse hook が exit 2 で fail させる。
4. **タイムアウト**: ラッパーが loop.yaml（`gradle_build_timeout_sec` 等）を適用する。長時間タスクは `GRADLE_TIMEOUT=秒` で上書き可。

## ビルドエラーの定石

- 依存解決失敗 → ネットワーク確認 → `run_gradle.sh --refresh-dependencies <task>`。
- Kotlin/Compose コンパイルエラー → `run_gradle.sh :app:compileDebugKotlin` で再現し、ログの `e:` 行を読む。
- キャッシュ起因の不可解な失敗 → `run_gradle.sh clean` 後に再ビルド（乱用しない。毎回 clean は遅い）。
- 環境破損（SDK 欠落等）→ `bash setup.sh` 再実行（冪等）。修復試行は `max_env_repair_attempts` 回まで。

## 完了条件

- 目的の Gradle/ADB 処理がラッパー経由で実行され、ログが `autodev/logs/<日付>/` に残っている。

## 関連参照

- 規約: `app/CLAUDE.md`
- 詳細仕様: 要件定義書 FR-5.13 / 付録E
