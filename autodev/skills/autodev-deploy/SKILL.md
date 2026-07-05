---
name: autodev-deploy
description: 「<source> から <target> へデプロイしてください」等のデプロイ指示を受けたときに発動。autodev/config/deploy.yaml に登録された環境（emulator / 開発者実機 device）間で、事前ゲート・ビルド/昇格・adb install・スモーク・記録・失敗時ロールバックを実施する標準手順。ストア公開は対象外。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-deploy skill

## 適用条件

- 「<source> から <target> へデプロイ」「<target> へデプロイ」等のデプロイ指示。
- source 省略時は既定のビルド元（emulator / 現行コード）。

## 前提

- 環境は `autodev/config/deploy.yaml` の `environments` に登録（kind=avd | adb-device）。
- デプロイ先は開発者のスマートフォン（`device`）。release ビルドは `autodev/secrets/keystore.properties` の独自 keystore で署名（setup.sh が自動生成。git 管理外）。
- `build_strategy`（既定 rebuild）: rebuild=現行コードからビルドし `autodev/artifacts/` へ世代保管 / promote=直近アーティファクト APK を再利用。

## 標準手順（D1〜D8）

1. **D1 解釈**: `deploy.sh <source> <target>` を **まず dry-run**（`--apply` なし）で実行し、計画と事前ゲート結果を提示。
2. **D2 事前ゲート**: `check_deploy_ready.sh <source> <target>`（promotion 許可・git clean・target デバイス可用性・署名情報・CHANGELOG）。NG なら中止。
3. **承認（重要・NFR-6.2.1 例外）**: `target.requires_approval=true`（実機 device は既定 true）なら、無確認自動化の例外。**必ずユーザーに明示確認を取り、許可された場合に限り** `--approve` を付与する。AI が独断で `--approve` を付けてはならない。
4. **D3 アーティファクト**: `resolve_artifact.sh` で strategy を解決。rebuild は `build.sh <build_type>` → `autodev/artifacts/app_<version>.apk` へ保管、promote は直近アーティファクトを採用。
5. **D4 マイグレーション**: Room migration は APK 内で実行される。事前に `check_room_schema.sh` で schema 変更時の Migration 定義・テストを確認。
6. **D5 リリース**: `deploy.sh ... --apply [--approve]` 本体がデバイス解決（avd→エミュレータ起動 / adb-device→実機）→ `adb install -r`。versionCode 後退・署名不一致は uninstall（**アプリデータ消失**）が必要なため、必ずユーザー確認。
7. **D6 スモーク**: `run_smoke_device.sh <serial> deploy_<target>`（起動マーカー + maestro/smoke.yaml + logcat クラッシュスキャン + スクショ）。
8. **D7 記録**: `autodev/state/deploys/<target>/<ts>.json`（source/target/git_sha/apk_path/version/smoke/approved）、進捗.md「デプロイ履歴」、CHANGELOG 追記、タグ。
9. **D8 失敗時**: `auto_rollback` で `rollback.sh <target> --apply`（前世代 APK へ。versionCode 後退の再 install は uninstall フォールバック=データ消失を伴う場合がある）。

## 完了条件

- 事前ゲート PASS／（要承認環境は）承認取得／install 成功／スモーク PASS／デプロイ記録出力。

## 失敗時の挙動

- 事前ゲート/承認 NG → 中止。スモーク失敗 → 自動ロールバック。dry-run で安全に再確認。

## 関連参照

- 設定: `autodev/config/deploy.yaml`
- スクリプト: `deploy.sh` / `check_deploy_ready.sh` / `resolve_artifact.sh` / `run_smoke_device.sh` / `rollback.sh`
- 詳細仕様: `autodev/docs/本番運用フェイズ補足.md`（デプロイ章）
