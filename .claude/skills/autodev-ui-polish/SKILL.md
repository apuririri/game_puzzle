---
name: autodev-ui-polish
description: システムループ S11（UIデザイン改善）で発動。全画面（Navigation の全ルート）の before スクショを HEADFUL で取得し、評価軸（視認性 / レイアウト / 一貫性 / 操作性 / 動的状態 / Material 3 / 余白 / アクセシビリティ）でユーザー使いやすさ・わかりやすさ・デザイン性の改善案を列挙、fix-loop で対応した上で after スクショを取得して before/after 差分とともに attestation を出力する標準手順。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-ui-polish skill

## 適用条件

- システムループの S10（全体結合確認・改善）完了後、S11 として自動発動。
- 単独発動も可（任意時点で「UI デザインを改善してください」等の指示）。

## 標準手順（UP1〜UP7 / 詳細は要件定義書 FR-5.18）

1. **UP1 全画面棚卸し**: `autodev/scripts/list_screens.sh` を実行。
   - `app/src/main/.../navigation/` の `NavHost` ルート定義（`composable("xxx")`）と `testTag("<画面>_root")` を解析し、ルート名・testTag・対応 Composable・主要要素を `autodev/state/ui_polish/inventory.json` に保存。
2. **UP2 before スクショ取得（HEADFUL）**: `autodev/scripts/capture_all_screens.sh --before` を実行。
   - `HEADFUL=1 start_emulator.sh` で GUI 表示エミュレータ確保（または実機）。
   - 各ルートを Maestro で順に表示し、`autodev/evidence/ui_polish/<screen>/before.png` を取得。
   - 動的状態が定義されている画面は `maestro/_polish/_state_<screen>.yaml` で loading / empty / error を発火させ `before_loading.png` `before_empty.png` `before_error.png` を別途撮影。
3. **UP3 デザイン評価**: 各 before スクショに対し `autodev/config/ui_polish.yaml::criteria[]` で定義された評価軸**全項目**で AI が評価。`autodev/scripts/check_ui_design.sh <screen>` が評価セクション欠落を fail させる。
   - 評価軸: 視認性（コントラスト / フォントサイズ / 余白）/ レイアウト（要素配置 / 整合性 / Material 3 ガイドライン）/ 一貫性（全体設計書 §共通スタイルとの整合）/ 操作性（タップ領域 48dp / アフォーダンス / ローディング状態の明示）/ 動的表示（遷移アニメ / スケルトン / エラー・エンプティ）/ アクセシビリティ（contentDescription / 色のみで情報を伝えない）
   - 各画面の改善案を `autodev/state/ui_polish/<screen>.json::issues[]` に列挙（重要度・対象 testTag・改善方針）。
4. **UP4 改善案の修正対応化**: 各 issue を `autodev/inputs/修正対応/修正_UI_<screen>_<項目>.md` として自動生成。共通スタイル変更（色 / タイポ / 余白 / コンポーネント）は `docs/設計/全体設計書.md::§共通スタイル` への反映指示を含めること。
5. **UP5 修正ループでの対応**: [autodev-fix-loop](../autodev-fix-loop/SKILL.md) を順次発動。各修正は実機検証必須（`run_real_device_check.sh`）。共通スタイル変更は他画面への影響を確認するため [autodev-design-sync](../autodev-design-sync/SKILL.md) で全体設計書と feature 設計書を再同期。
6. **UP6 after スクショと差分**: `autodev/scripts/capture_all_screens.sh --after` を実行。
   - 全画面 `autodev/evidence/ui_polish/<screen>/after.png` を取得（動的状態も同様）。
   - `autodev/evidence/ui_polish/<screen>/diff.md` に before/after の相対パスとリンクを出力。
   - `autodev/scripts/check_ui_polish_evidence.sh` で全画面の before/after 揃いを機械検証。
7. **UP7 attestation 出力**: `autodev/state/attestations/ui_polish.json` を出力:
   - `inventory`: `autodev/state/ui_polish/inventory.json` パス
   - `screens`: 画面ごとの before/after パス + issues + 対応結果
   - `improvements`: 修正対応 attestation 一覧
   - `closed_at`: タイムスタンプ

## フェーズ省略・打ち切りの禁止（CLAUDE_MAIN.md 規約12〜15）

- UP1〜UP7 のいずれも自己判断で省略してはならない。
- 「画面数が多いのでスクショは一部だけ」「動的状態は省略」「after スクショは将来対応」等は規約違反。
- 動的状態の発火が困難な画面は `autodev/config/ui_polish.yaml::dynamic_state_optional` に明示登録した場合に限り省略可（before/after の通常スクショは必須）。

## 完了条件

- 全 Navigation ルートに `before.png` と `after.png` が存在
- `check_ui_polish_evidence.sh` PASS
- 全 UI 修正対応の attestation が done
- `autodev/state/attestations/ui_polish.json` 出力済み
- `autodev/scripts/check_no_skip_excuses.sh --target ui_polish` PASS

## 失敗時の挙動

- UP2 / UP6 スクショ取得失敗 → デバイス再確保 → 該当ルートのみリトライ。3 回連続失敗で blocked。
- UP3 評価軸の欠落 → `check_ui_design.sh` が fail させる。AI が再評価して埋める。
- UP5 修正の実機検証 fail → 該当 fix-loop でリトライ（`max_iterations_per_fix_loop` 超過で blocked）。

## 関連参照

- [autodev-fix-loop](../autodev-fix-loop/SKILL.md) / [autodev-device-verify](../autodev-device-verify/SKILL.md) / [autodev-design-sync](../autodev-design-sync/SKILL.md)
- 設定: `autodev/config/ui_polish.yaml`
- スクリプト: `list_screens.sh` / `capture_all_screens.sh` / `check_ui_design.sh` / `check_ui_polish_evidence.sh`
- 詳細仕様: 要件定義書 FR-5.18 / 9.2(S11)
