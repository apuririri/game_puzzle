---
name: autodev-fix-loop
description: 修正対応モード起動時、およびペルソナテスト由来の改善要望に対応するときに発動。修正対応書を入力に、影響範囲分析を強化した上でタスク分割・設計書紐付け・イテレーション実行・要件⇄影響範囲⇄実装トレーサビリティ照合（R5.5）・実機検証・ペルソナ駆動テスト（R6.5）・設計書同期を行い、コミット・プッシュまで（R1〜R7）を完結させる標準手順。
required_doc_version: "5.2"
---

<!-- version: 2.1 -->

# autodev-fix-loop skill

## 適用条件

- 起動プロンプト「修正_<修正名>.mdの修正を自動で対応してください」を受信したとき。
- ペルソナテストで生成された改善要望 `autodev/inputs/修正対応/修正_<改善名>.md` を順次対応するとき（system / feature / fix の各スコープから呼ばれうる）。

## 標準手順（R1〜R7 / 詳細は要件定義書 9.4）

1. **R1**: 修正対応書を確認・整理。不明点があれば最小限の質問。`autodev/state/loops/<修正名>.json`（`target_type: "fix"`）を生成。フロントマターに `source_scope` / `severity` がある場合は state にも転記する（R6.5 のスキップ判定で参照する）。
2. **R2 影響範囲分析**: 修正対応書の影響範囲セクション + 実装から、変更が及ぶ箇所を特定。観点: 画面（Composable）・Navigation ルート・ViewModel/StateFlow・UseCase・Room Entity/Dao（schema 変更の有無）・DataStore キー・Retrofit API・権限・既存の Compose UI Test / Maestro flow。UI 動線・データフロー・共通機能経由の波及も含める。結果を `impact_analysis` に記録（`files / screens / room_entities / dao / apis / permissions`）。
3. **R3**: 影響範囲の `docs/設計/features/<関連機能>.md`（必要なら全体設計書）を確認し修正方針を検討。
4. **R4**: タスク列に分割し `autodev/state/tasks/<修正名>.json` に記録。各タスクに `design_doc_ref`。影響範囲の全箇所がタスク化されているか `check_task_design_link.sh` で確認。
5. **R5**: 各タスクをイテレーションループ（I0〜I8）で直列実行。
6. **R5.5 要件⇄影響範囲⇄実装 トレーサビリティ照合**（[autodev-coverage-check](../autodev-coverage-check/SKILL.md) を `scope=fix:<修正名>` で発動 / FR-5.21.3）:
   - `loop.yaml::fix_loop.traceability_enabled=false` のときはスキップ（PASS 扱いで R6 へ進む / 規約15 ホワイトリスト）。AI 判断による省略は禁止。
   - `autodev/scripts/check_traceability.sh <修正名> --scope fix --cycle <N>` を実行。
   - 検査対象: 修正対応書の受け入れ条件・影響範囲セクション、R2 で記録された `impact_analysis`（`files / screens / room_entities / dao / apis / permissions`）、`tasks/<修正名>.json`、変更ファイル。
   - layer × カテゴリ マッピング は F5.5 と同じ（FR-5.21.2.3 / 画面要素=`[ui]`+testTag / ユーザー操作=`[ui,viewmodel]` / エラーケース=`[ui,viewmodel,domain]` / データモデル=`[data]`+Room Entity / 受け入れ条件=`[test]`+Maestro/androidTest）。
   - 出力 `state/traceability/<修正名>.json` の `items[]` を AI が点検し、`covered=false` 項目を実装の実体で確認。
     - false-negative は `items[].covered_by_ai=true` + `items[].ai_reason="<根拠>"` を JSON に書き込む（言い訳語禁止 / 規約14 / 次サイクルで承継）。
     - 真のギャップは追加タスクとして `tasks/<修正名>.json::tasks[]` に push（`source: "traceability_gap"` / `design_doc_ref` 必須 / `layer` 必須）。
   - 真のギャップがあれば **R5 イテレーションループへ戻り**、追加タスクを直列消化 → R5.5 再走査。
   - 上限: `loop.yaml::fix_loop.traceability_max_cycles`（既定 2）。超過時は残ギャップを `blocking_issues` に集約 → `blocked=true` で停止（R6 へ進まない / 規約12）。
   - 完了時に `state/loops/<修正名>.json::r5_5_result.traceability_ref` を更新し R6 へ進む。
7. **R6**: 修正全体レビュー + 影響範囲を実機検証（`run_real_device_check.sh <修正名>`）。受け入れ条件 + 既存機能が壊れていないこと（関連 Compose UI Test / Maestro flow の回帰）を確認。fail なら R5 に戻る。
8. **R6.5 ペルソナ駆動テスト**（[autodev-persona-test](../autodev-persona-test/SKILL.md) を `scope=fix:<修正名>` で発動 / FR-5.9.9）:
   - **判定主体**: R6.5 突入時、AI が **R1 で state に転記済みの `source_scope` / `severity` フィールド** と loop.yaml の閾値を読み、下記スキップ条件のいずれかに該当するかを判定する。スキップ時は `autodev/state/persona_tests/<番号>.json` を `r6_5_skipped: true` / `r6_5_skip_reason: <理由>` で記録し、R7 へ進む（このとき `check_persona_test_evidence.sh` は PASS 扱い）。スクリプト側でのフロントマター解析は行わない（AI 判定）。
   - **スキップ条件①**: `loop.yaml::fix_loop.persona_test_enabled=false`（PASS 扱いで R7 へ進む / 段階導入用 / 規約15 ホワイトリスト）。
   - **スキップ条件②（severity 足切り）**: 修正対応書の `severity` が `loop.yaml::fix_loop.persona_test_severity_threshold`（既定 `low`）未満の場合はスキップ。`never` 設定時は常にスキップ。比較基準は `low < medium < high`。
   - **スキップ条件③（ループ無限化防止）**: 修正対応書のフロントマター `source_scope` が `feature` または `fix` の場合（＝ペルソナテスト由来の改善要望に対応している修正）、本 R6.5 は**スキップする**。再ペルソナテストは呼び出し元（F6.5 / R6.5）のサイクル制御に委ねる。
   - 前段: `autodev/scripts/ensure_personas.sh` を実行し、既存 `personas.json` を再利用 or 不在時は AI がフォールバック定義。
   - シナリオ: R2 の `impact_analysis` を入力に、修正対象 + 影響範囲動線をシナリオの中心にする。**リグレッション観点（影響範囲の既存機能が壊れていない）を必ず1類以上含める**。各ペルソナ × 目的達成型 / 迷い・誤操作型 / エラーケース型の3類を最低含み、Android 固有操作を最低1つ織り込む。
   - 実機実行: `autodev/scripts/run_persona_tests.sh <番号> --scope fix:<修正名>` でデバイス確保 + 最新 debug ビルドインストール + Maestro flow 実行。証跡は `autodev/evidence/persona_tests/<番号>/fix_<修正名>/`。
   - 改善要望は `修正_persona_fix_<修正名>_<改善名>.md` として自動生成 → 自身（autodev-fix-loop）のサブループで R7 クローズ前にすべて消化（UI 改善要望も同時吸収）。サブ修正の R6.5 はスキップ条件③によりスキップされる。
   - 上限: `loop.yaml::fix_loop.persona_test_max_cycles`（既定 2）を超えても残課題があれば `blocking_issues` に集約し、`blocked=true` で停止（R7 には進まない）。
   - 完了時に `autodev/state/persona_tests/<番号>.json` を `scope=fix` / `target=<修正名>` / `triggered_from=R6.5` で記録。
9. **R7 クローズ**: 機能ループ F7 と同じゲート群（`check_traceability.sh <修正名> --scope fix --gate`（R5.5 の最終確認ゲート / FR-5.21.3）/ `check_persona_test_evidence.sh <修正名> fix`（FR-5.9.9）を含む）→ attestation（`impact_analysis` / `persona_test_ref` / `traceability_ref` / `traceability_passed` を含む）→ `autodev/scripts/archive_critical_evidence.sh autodev/state/attestations/<修正名>.json` で証跡を永続化（案7）→ コミット・プッシュ。

## 完了条件

- 機能ループに準ずる / `impact_analysis` 記録済み / R5.5 トレーサビリティ PASS（または `fix_loop.traceability_enabled=false`）/ R6.5 PASS（または無効化条件によりスキップ）/ attestation に `persona_test_ref` / `traceability_ref` / `traceability_passed` を含む。

## 上限と終了条件（loop.yaml 連動 / 案3）

- **`max_iterations_per_fix_loop`**（既定 8）: R5 内のイテレーション数上限。超過時は **blocking_issues** として attestation に残し、状態 `blocked=true` で停止して人手判断を仰ぐ。
- **`max_fix_cycles_per_persona_run`**（既定 2）: ペルソナテスト由来の改善要望対応で「修正→再ペルソナ→新たな改善要望→修正」の再帰サイクル上限（scope=system 由来）。超過時は残った改善要望を `blocking_issues` として `state/persona_tests/<番号>.json` に書き戻し、修正ループ終了。
- **`re_persona_after_fix`**: 修正ループ完了後の再ペルソナテスト方針（`all` / `minor_only` / `never`）。`minor_only` の場合、改善要望リストに `severity: high` 以上が含まれていた場合のみ再ペルソナテストを発動。
- **`fix_loop.persona_test_max_cycles`**（既定 2）: R6.5 内の「修正→再ペルソナ」上限。
- **`fix_loop.persona_test_severity_threshold`**（既定 `low`）: R6.5 発動の足切り。`low` 未満は R6.5 スキップ。`never` で常時スキップ。
- **`fix_loop.traceability_max_cycles`**（既定 2）: R5.5 内の「ギャップ検出→追加タスク→再走査」上限。超過時は `blocked=true` で停止（R6 へ進まない）。
- **`fix_loop.traceability_enabled`**（既定 true）: false で R5.5 をスキップ（段階導入用 / 規約15 ホワイトリスト）。

## 失敗時の挙動

- 実機検証 fail → イテレーションへ戻る。`max_iterations_per_fix_loop` 超過で停止。
- R5.5 のサイクル `fix_loop.traceability_max_cycles` 超過 → 残ギャップを `blocking_issues` に集約し `blocked=true` で停止（R6 へ進まない / 規約12）。
- R6.5 のサブ fix-loop で `fix_loop.persona_test_max_cycles` 超過 → `blocking_issues` に集約し `blocked=true` で停止（R7 へ進まない）。
- 修正サイクル無限化を防ぐため、`max_fix_cycles_per_persona_run` 超過時は残課題を `blocking_issues` に集約して報告のみで終了。

## 関連参照

- [autodev-feature-loop](../autodev-feature-loop/SKILL.md) / [autodev-device-verify](../autodev-device-verify/SKILL.md) / [autodev-design-sync](../autodev-design-sync/SKILL.md)
- [autodev-coverage-check](../autodev-coverage-check/SKILL.md)（R5.5 から発動）
- [autodev-persona-test](../autodev-persona-test/SKILL.md)（R6.5 から発動）
- 詳細仕様: 要件定義書 9.4 / FR-5.11 / FR-5.9.9 / FR-5.21.3
