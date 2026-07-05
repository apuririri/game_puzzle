---
name: autodev-integration-verify
description: システムループ S10（全体結合確認・改善）で発動。実装中に残っているモック/スタブ/TODO をプロダクション側から廃止して実プログラムに置換し、リリース後の挙動を想定して全機能と機能横断シナリオを HEADFUL 実機で通し、不具合・未実装・考慮漏れ・ユーザー利用目的視点での改善を発見して fix-loop で対応する標準手順。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-integration-verify skill

## 適用条件

- システムループの S9（全機能ループ + 最終ペルソナテスト）完了後、S10 として自動発動。
- 単独発動も可（システム開発の任意時点で「全体結合確認をしてください」等の指示）。

## 標準手順（IV1〜IV6 / 詳細は要件定義書 FR-5.17）

1. **IV1 モック/スタブ残存検出**: `autodev/scripts/check_no_mocks.sh` を実行。`app/src/main/`（テストコード除外）から `Mock` `Fake` `Stub` `Dummy` `TODO` `FIXME` `XXX` `HACK` などの暫定実装パターンを検出。許容パターンは `autodev/config/integration.yaml::allowlist` で管理。検出件数が 0 でない場合は IV2 に進む。
2. **IV2 モック廃止 → 実プログラム化**: 検出箇所ごとに以下を生成:
   - `autodev/inputs/修正対応/修正_デモック_<モジュール>.md`（対象パス、現在の暫定実装、置換方針＝全体設計書 / 機能設計書のどのセクションを実装すべきか、影響範囲）
   - [autodev-fix-loop](../autodev-fix-loop/SKILL.md) を順次発動して実プログラムへ置換。完了後 IV1 を再走し、`check_no_mocks.sh` PASS まで反復。
3. **IV3 全機能統合実機検証**: `autodev/scripts/run_integration_check.sh` を実行。
   - HEADFUL モードでエミュレータ起動（`HEADFUL=1`）。実機が利用可能なら実機優先。
   - クリーンアンインストール → 最新ビルド install → 起動。
   - 全機能 Maestro flow を順次実行。
   - 機能横断シナリオ（`maestro/_integration/*.yaml`）を実行: ログイン→主要動線→ログアウト連結 / アプリ kill→再起動 状態保持 / バックグラウンド退避→復帰 / 機内モード（オフライン）→復帰 / 画面回転 / 権限拒否時の挙動。
   - 各画面遷移ごとにスクショ + logcat ダンプを `autodev/evidence/_integration/` へ保存。
   - logcat クラッシュスキャン（FATAL / ANR / 統一タグの ERROR）。
4. **IV4 利用目的視点の評価**: 各ペルソナ（`autodev/state/personas/personas.json`）について、主用途を遂行する1本のシナリオを Maestro で実行し、目的達成可否・迷い・誤操作・期待外れを AI が評価。[autodev-persona-test](../autodev-persona-test/SKILL.md) を `trigger=integration` で再利用しても可。発見した不具合・未実装・考慮漏れ・改善要望を `autodev/inputs/修正対応/修正_統合_<項目>.md` として自動生成。
5. **IV5 修正と再走**: 生成された修正対応を fix-loop で順次対応。完了後 IV3 を再走。`autodev/config/integration.yaml::max_integration_cycles`（既定 3）超過時は残課題を `autodev/state/attestations/integration.json::blocking_issues` に転記し `blocked=true` で停止。
6. **IV6 attestation 出力**: `autodev/state/attestations/integration.json` を出力:
   - `no_mocks_gate`: PASS / 検出残数
   - `integration_scenarios`: 実行 flow 一覧と結果
   - `evidence`: `autodev/evidence/_integration/` 配下のスクショ + logcat パス
   - `improvements`: 派生改善要望と対応結果
   - `closed_at`: タイムスタンプ

## フェーズ省略・打ち切りの禁止（CLAUDE_MAIN.md 規約12〜15）

- IV1〜IV6 のいずれも自己判断で省略してはならない。
- 「モックは残っていても良い」「実機検証は次セッションで」「改善要望は将来対応」等は規約違反。
- 実施不能なら `set_current.sh system "" S10_integration "" "IV<番号>" true "<理由>"` で人手介入待ち停止。

## 完了条件

- `check_no_mocks.sh` PASS（プロダクション側のモック/スタブ/TODO 残存なし）
- 統合実機シナリオ all PASS（logcat クラッシュなし）
- 派生改善要望すべて修正完了 or `blocking_issues` に明示転記
- `autodev/state/attestations/integration.json` 出力済み
- `autodev/scripts/check_no_skip_excuses.sh --target integration` PASS

## 失敗時の挙動

- IV3 統合シナリオ fail → fail 内容を入力に該当機能の修正ループへ。
- `max_integration_cycles` 超過 → blocking_issues に残課題を明記して停止。
- HEADFUL エミュレータ起動不能 → `check_android_setup.sh` で環境確認、それでも不能なら blocked。

## 関連参照

- [autodev-fix-loop](../autodev-fix-loop/SKILL.md) / [autodev-persona-test](../autodev-persona-test/SKILL.md) / [autodev-device-verify](../autodev-device-verify/SKILL.md)
- 設定: `autodev/config/integration.yaml`
- スクリプト: `check_no_mocks.sh` / `run_integration_check.sh`
- 詳細仕様: 要件定義書 FR-5.17 / 9.2(S10)
