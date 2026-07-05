---
name: autodev-feature-loop
description: 機能単位開発モード起動時およびシステムループ S9 の各機能開発時に発動。1機能を直列イテレーションループで開発し、設計書同期・タスク-設計書紐付け・要件⇄設計⇄実装トレーサビリティ照合（F5.5）・実機検証（エミュレータ/実機 + Compose UI Test/Maestro）・ペルソナ駆動テスト（F6.5）を経て F7 のクローズ（ゲート→attestation→コミット・プッシュ）まで完結させる標準手順。
required_doc_version: "5.2"
---

<!-- version: 2.1 -->

# autodev-feature-loop skill

## 適用条件

- 起動プロンプト「機能要件_<機能名>.mdの機能を自動で開発してください」を受信したとき。
- システムループ S9 の各機能開発フェーズ。

## 標準手順（F1〜F7 / 詳細は要件定義書 9.3）

1. **F1**: 機能要件を読み整理。不明点があれば最小限の質問。`autodev/state/loops/<機能名>.json` を生成。
2. **F2**: 既存実装と設計書を確認。`docs/設計/features/<機能名>.md` が無ければ新規作成(全体設計書から骨組み + 機能要件書反映。画面の testTag 一覧を含める)。
3. **F3**: タスク列に分割し `autodev/state/tasks/<機能名>.json` に記録。分割観点: 画面（Compose）/ ViewModel・StateFlow / domain（UseCase）/ data（Room Entity・Dao / Retrofit）/ テスト（JUnit・Compose UI Test・Maestro）。各タスクに `design_doc_ref`（file + section）と `layer`（`ui` / `viewmodel` / `domain` / `data` / `test`）を必ず設定。`autodev/scripts/check_task_design_link.sh <機能名>` で分割漏れチェック。
   - **UI 必須機能の判定**: 機能要件書に画面・UI操作の受け入れ条件が含まれる場合、`layer="ui"` のタスクを**少なくとも1件**生成すること（規約15）。UI 実装を「後続作業」「将来対応」として除外することは禁止。
   - **DB 基盤・初期化スクリプト等で UI が本当に不要な機能**は、`system.json::features[].ui_required = false` を明示すること。これが無い限り `check_system_completion.sh` は UI 層タスク不在を fail として扱う。
4. **F4**: 各タスクをイテレーションループ（I0〜I8）で直列実行。[autodev-gradle-env](../autodev-gradle-env/SKILL.md) / [autodev-design-sync](../autodev-design-sync/SKILL.md) / [autodev-device-verify](../autodev-device-verify/SKILL.md) を併用。主要UI要素には必ず testTag を付与（絶対規約10）。
5. **F5**: 機能全体レビュー。変更ファイル・関連設計書・タスク対応を再点検。問題があれば修正イテレーション追加。
6. **F5.5 要件⇄設計⇄実装 トレーサビリティ照合**（[autodev-coverage-check](../autodev-coverage-check/SKILL.md) を `scope=feature:<機能名>` で発動 / FR-5.21.2）:
   - `loop.yaml::feature_loop.traceability_enabled=false` のときはスキップ（PASS 扱いで F6 へ進む / 規約15 ホワイトリスト）。AI 判断による省略は禁止。
   - `autodev/scripts/check_traceability.sh <機能名> --scope feature --cycle <N>` を実行。
   - **layer × カテゴリ マッピング**: 画面要素=`[ui]`+testTag grep / ユーザー操作=`[ui,viewmodel]` / エラーケース=`[ui,viewmodel,domain]` / データモデル=`[data]`+Room Entity / 受け入れ条件=`[test]`+Maestro/androidTest（FR-5.21.2.3）。
   - `system.json::features[<機能名>].ui_required==false` の場合は画面要素/ユーザー操作の検査を明示的にスキップ（FR-5.21.2.4）。
   - 出力 `state/traceability/<機能名>.json` の `items[]` を AI が点検し、`covered=false` 項目について実装の実体（Compose Composable / ViewModel / UseCase / Room Entity / Maestro flow / Compose UI Test）を直接確認。
     - false-negative（grep ヒットしなかったが実装あり）の場合は `items[].covered_by_ai=true` + `items[].ai_reason="<根拠>"` を JSON に書き込む（言い訳語禁止 / 規約14）。次サイクルでスクリプトが `(category, item)` 一致で承継するため、追加タスク実装後の再走査でも PASS は維持される。
     - 真のギャップは追加タスクとして `tasks/<機能名>.json::tasks[]` に push（`source: "traceability_gap"` / `design_doc_ref` 必須 / `layer` 必須 / `status: "pending"`）。
   - 真のギャップがある場合は **F4 イテレーションループへ戻り**、追加タスクを直列消化 → F5 全体レビュー → F5.5 再走査。
   - 上限: `loop.yaml::feature_loop.traceability_max_cycles`（既定 2）。超過時は残ギャップを `blocking_issues` に集約 → `blocked=true` で停止（F6 へ進まない / 規約12）。
   - 完了時に `state/loops/<機能名>.json::f5_5_result.traceability_ref` を更新し F6 へ進む。
7. **F6**: 機能実機検証。`autodev/scripts/run_real_device_check.sh <機能名>` で受け入れ条件すべてをエミュレータ/実機で通す（スクショ + logcat 証跡）。fail なら F4 に戻る。
8. **F6.5 ペルソナ駆動テスト**（[autodev-persona-test](../autodev-persona-test/SKILL.md) を `scope=feature:<機能名>` で発動 / FR-5.9.8）:
   - `loop.yaml::feature_loop.persona_test_enabled=false` のときはスキップ（PASS 扱いで F7 へ進む / 規約15 ホワイトリスト対象）。AI 判断による省略は禁止。
   - 前段: `autodev/scripts/ensure_personas.sh` を実行し、既存 `personas.json` を再利用 or 不在時は AI がフォールバック定義（既存 ID は書き換えない）。
   - シナリオ: 当該新機能を主動線とし、全体設計書から特定した既存連携動線（起動 → 新機能 / 新機能 → 既存共通機能 等）も含める。各ペルソナ × 目的達成型 / 迷い・誤操作型 / エラーケース型の3類を最低含み、**Android 固有操作（戻る / 回転 / バックグラウンド退避→復帰 / プロセス kill / 機内モード / 権限拒否）を最低1つ織り込む**。Maestro flow の要所で `takeScreenshot` を取り、改善要望抽出時の画面キャプチャを確実に得る。
   - 実機実行: `autodev/scripts/run_persona_tests.sh <番号> --scope feature:<機能名>` でデバイス確保 + 最新 debug ビルドインストール + Maestro flow 実行。証跡は `autodev/evidence/persona_tests/<番号>/feature_<機能名>/`。
   - 改善要望は `修正_persona_feature_<機能名>_<改善名>.md` として自動生成 → [autodev-fix-loop](../autodev-fix-loop/SKILL.md) のサブループで F7 クローズ前にすべて消化（UI 改善要望も同時吸収）。
   - 上限: `loop.yaml::feature_loop.persona_test_max_cycles`（既定 2）を超えても残課題があれば `blocking_issues` に集約し、`blocked=true` で停止（F7 には進まない）。
   - 完了時に `autodev/state/persona_tests/<番号>.json` を `scope=feature` / `target=<機能名>` / `triggered_from=F6.5` で記録。
9. **F7 クローズ手順（順序が重要）**:
   1. `autodev/scripts/check_design_sync.sh --gate`
   2. `autodev/scripts/check_dead_assets.sh --gate`
   3. `autodev/scripts/check_room_schema.sh --gate`（Room schema 変更があった機能）
   4. `autodev/scripts/check_testtag_coverage.sh`（警告は解消を推奨）
   5. `autodev/scripts/check_traceability.sh <機能名> --scope feature --gate`  ← **F5.5 の最終確認ゲート（FR-5.21.2）**
   6. `autodev/scripts/check_real_device_evidence.sh <機能名>`
   7. `autodev/scripts/check_persona_test_evidence.sh <機能名> feature`  ← **F6.5 の attestation ゲート（FR-5.9.8）**
   8. `autodev/scripts/check_progress_md_sync.sh`
   9. attestation 初版を `autodev/state/attestations/<機能名>.json` に出力（`closed_at` 記録 / `persona_test_ref: <番号>` / `traceability_ref` / `traceability_passed` を含める）。
   10. **証跡の永続化**: `autodev/scripts/archive_critical_evidence.sh autodev/state/attestations/<機能名>.json` を実行し、`evidence.screenshots` / `evidence.logcat` を `autodev/evidence/_archived/<機能名>/` へコピー（案7 / retention.yaml の prune 対象外、無期限保持）。
   11. 進捗.md 再生成。
   12. コミット（`iter:` ではなく機能完了コミット）・プッシュ。

## フェーズ省略・タスク未完了でのクローズ禁止（CLAUDE_MAIN.md 規約12〜14）

- F1〜F7 のいずれのステップも、AI が自己判断で省略・後回し・打ち切ることを禁止する。F6.5 も同様。
- **「タスクのうち UI を後続作業として残す」「テストは将来書く」「設計書同期は次セッションで」「ペルソナテストはコンテキストが圧迫するので飛ばす」等は規約違反**。
- 残存タスクを残したいなら、`autodev/inputs/修正対応/修正_<理由>.md` を新規生成して修正ループに渡す。それ以外の方法でタスクを未完了のまま機能クローズしてはならない。
- 完了宣言（「✅ 機能完了」「機能ループ完了」「mode を空にする」等）は、F7 の全ゲート PASS + `system.json::features[<本機能>].status="done"` + attestation 出力済み + `persona_test_ref` 記載済み（または `feature_loop.persona_test_enabled=false`）の後にだけ許される。

## 完了条件

- 全タスク `status="done"`（残存タスクをスキップ理由で除外することは禁止）
- F5.5 トレーサビリティ PASS（または `feature_loop.traceability_enabled=false`）
- F6 実機検証 PASS（実機 UI 動線含む）
- F6.5 ペルソナテスト PASS（または `feature_loop.persona_test_enabled=false`）
- 各ゲート（F7 の 12 ステップ / F5.5 ゲート `check_traceability.sh --scope feature --gate` / F6.5 ゲート `check_persona_test_evidence.sh <機能名> feature` を含む）PASS
- attestation 出力済み（`persona_test_ref` / `traceability_ref` / `traceability_passed` を含む）
- 進捗.md 同期済み
- `autodev/scripts/check_no_skip_excuses.sh --target <機能名>` PASS
- プッシュ完了

## 失敗時の挙動

- 実機検証 fail → イテレーションループに戻る。最大試行回数（`loop.yaml` の `max_retry_per_loop`、既定 10）超過で停止。
- 環境破損 → 修復試行（既定 3回）。超過で停止。
- F5.5 のサイクル `feature_loop.traceability_max_cycles` 超過 → 残ギャップを `blocking_issues` に集約し `blocked=true` で停止（F6 へ進まない / 規約12）。
- F6.5 のサブ fix-loop で `feature_loop.persona_test_max_cycles` 超過 → `blocking_issues` に集約し `blocked=true` で停止（F7 へ進まない）。
- 上記以外の事情（時間・スコープ・トークン）でフェーズ・タスクを省略してはならない。停止が必要なら必ず `set_current.sh ... true "<理由>"` で人手介入待ちに遷移する。

## 関連参照

- [autodev-gradle-env](../autodev-gradle-env/SKILL.md) / [autodev-device-verify](../autodev-device-verify/SKILL.md) / [autodev-design-sync](../autodev-design-sync/SKILL.md) / [autodev-progress-md](../autodev-progress-md/SKILL.md)
- [autodev-coverage-check](../autodev-coverage-check/SKILL.md)（F5.5 から発動）
- [autodev-persona-test](../autodev-persona-test/SKILL.md) / [autodev-fix-loop](../autodev-fix-loop/SKILL.md)（F6.5 から発動）
- 詳細仕様: 要件定義書 9.3 / 9.5 / FR-5.2〜FR-5.17 / FR-5.9.8
