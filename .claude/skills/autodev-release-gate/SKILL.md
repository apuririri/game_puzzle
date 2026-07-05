---
name: autodev-release-gate
description: システムループ S14（デプロイ・リリース最終確認）で発動。本番リリース可能な状態かを11種の静的ゲートとリリース署名済み APK の実機スモークで厳しくチェックし、検出された不具合を fix-loop で全 PASS まで反復対応した上で「即リリース可」判定 attestation を出力して device へのデプロイを即実行可能な状態にする標準手順。ストア公開は対象外。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-release-gate skill

## 適用条件

- システムループの S13（顧客向けドキュメント整備）完了後、S14 として自動発動。
- 単独発動も可（任意時点で「リリース最終確認をしてください」等の指示）。

## 標準手順（RG1〜RG5 / 詳細は要件定義書 FR-5.19）

1. **RG1 静的リリースゲート群**: `autodev/scripts/check_release_ready.sh` を実行。以下を順次呼び出し、1 件でも fail で RG3 へ:
   - `check_release_clean.sh`（autodev/.claude 依存なし / 既存）
   - `check_no_mocks.sh`（プロダクション側のモック・スタブ・TODO 残存なし）
   - `check_design_sync.sh --gate`（設計書同期 / 既存）
   - `check_room_schema.sh --gate`（Room schema + Migration テスト / 既存）
   - `check_dead_assets.sh --gate`（既存）
   - `check_testtag_coverage.sh`（既存）
   - `check_no_debug_artifacts.sh`（`println` / `Log.v` / `BuildConfig.DEBUG` 分岐の本番側残骸 / `localhost` / dev URL / `Log.setLoggable(true)` 残存）
   - `check_manifest_release.sh`（`android:debuggable=false` / `usesCleartextTraffic` 方針 / `allowBackup` 方針 / `network_security_config` 整合 / 過剰権限 / `exported` 明示）
   - `check_release_build.sh`（`build.sh release` PASS / minify / R8 / 署名検証 / `versionCode` 単調増加）
   - `check_release_strings.sh`（ハードコード文字列の locale 露出 / 未翻訳 placeholder 検出）
   - `check_dependencies.sh`（gradle dependencies の SNAPSHOT 禁止 / version catalog 整合）
2. **RG2 リリースビルドの本番想定スモーク**: `autodev/scripts/run_release_smoke.sh` を実行。
   - `build.sh release` で署名済み APK を生成（`autodev/artifacts/`）。
   - 実機（または HEADFUL emulator）で `uninstall.sh` クリーンアンインストール → `install.sh` で release APK をインストール → `run.sh` で起動。
   - `run_smoke_device.sh <serial> release_smoke` で `maestro/smoke.yaml` 実行 + logcat クラッシュスキャン。
   - 続けて `maestro/*.yaml` の全 flow を実行（リリースビルドでの挙動確認）。
   - 証跡は `autodev/evidence/_release/` に保存。
3. **RG3 不具合 → 修正ループ**: RG1 / RG2 で fail した項目を `autodev/inputs/修正対応/修正_リリース_<項目>.md` として自動生成し [autodev-fix-loop](../autodev-fix-loop/SKILL.md) で順次対応。完了後 RG1 → RG2 を再走。`autodev/config/release.yaml::max_release_cycles`（既定 5）超過で `blocking_issues` 明記の上 blocked。
4. **RG4 リリース判定 attestation**: 全 PASS で `autodev/state/attestations/release.json` を出力:
   - `decision`: `"releasable"`
   - `apk_path`: 署名済み APK パス（`autodev/artifacts/app_<version>.apk`）
   - `signing`: 署名情報（fingerprint / keystore alias）
   - `version`: `versionCode` / `versionName`
   - `gates`: 11 種ゲートの結果一覧
   - `release_smoke`: RG2 の実行結果と証跡パス
   - `closed_at`: タイムスタンプ
5. **RG5 デプロイ指示の提示**: 進捗.md に以下を明示:
   - 「`emulator から device へデプロイしてください` で即実行可能」
   - 対象 APK パス / 承認が必要な旨（規約7 / NFR-6.2.1）
   - 実 deploy は [autodev-deploy](../autodev-deploy/SKILL.md) に委譲。**本 skill の責務は「即デプロイ可能な状態を機械保証する」までであり、device への実デプロイは行わない**。

## フェーズ省略・打ち切りの禁止（CLAUDE_MAIN.md 規約12〜15）

- RG1〜RG5 のいずれも自己判断で省略してはならない。
- 「リリースビルドのスモークは時間がかかるので省略」「ゲートの一部は warning 扱いに緩和」等は規約違反。
- ゲートの allowlist 追加は `autodev/config/release.yaml` の正規ルートのみ。コード内 `// NOLINT` 等での回避は禁止。
- 実 deploy（device への install）は本 skill では行わない。ユーザー承認後 [autodev-deploy](../autodev-deploy/SKILL.md) に委譲する。

## 完了条件

- `check_release_ready.sh --gate` PASS（11 種すべて PASS）
- `run_release_smoke.sh` PASS（クラッシュ 0 / 全 flow PASS）
- `autodev/state/attestations/release.json` 出力済み（`decision: "releasable"`）
- `autodev/scripts/check_no_skip_excuses.sh --target release` PASS

## 失敗時の挙動

- RG1 / RG2 fail → RG3 fix-loop → 再走。`max_release_cycles` 超過で残課題を `blocking_issues` に集約して停止。
- 署名 keystore 不在 → `autodev/secrets/keystore.properties` の存在確認、`setup.sh` 再実行で自動生成（git 管理外）。
- 実機 / HEADFUL emulator 確保不能 → `check_android_setup.sh` で原因特定、不能なら blocked。

## 関連参照

- [autodev-fix-loop](../autodev-fix-loop/SKILL.md) / [autodev-device-verify](../autodev-device-verify/SKILL.md) / [autodev-deploy](../autodev-deploy/SKILL.md)
- 設定: `autodev/config/release.yaml` / `autodev/secrets/keystore.properties`
- スクリプト: `check_release_ready.sh` / `check_no_mocks.sh` / `check_no_debug_artifacts.sh` / `check_manifest_release.sh` / `check_release_build.sh` / `check_release_strings.sh` / `check_dependencies.sh` / `run_release_smoke.sh`
- 詳細仕様: 要件定義書 FR-5.19 / 9.2(S14)
