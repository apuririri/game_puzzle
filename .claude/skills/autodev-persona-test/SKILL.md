---
name: autodev-persona-test
description: システムループ S7/S9（3機能完了ごと・全機能完了後）、機能ループ F6.5（機能単位開発モード・システムループ S9 内の各機能ループ）、修正ループ R6.5（修正対応モード）で発動。事前定義した複数ペルソナを順にロールプレイし、目的達成型・迷い誤操作型・エラーケース型 + Android 固有操作のシナリオをエミュレータ/実機（Maestro）で実行し、画面キャプチャと logcat を取得して機能改善要望・UI改善要望を列挙し、修正対応ファイルとして自動生成する標準手順。
required_doc_version: "5.2"
---

<!-- version: 2.0 -->

# autodev-persona-test skill

## 適用条件

本 skill は次の3スコープで発動する。スコープに応じてシナリオ範囲と発動条件が変わる。

| scope | 発動契機 | シナリオ範囲 |
|---|---|---|
| `system` | システムループ S7（計画）/ S9（実施）。3機能完了ごと + 全機能完了後（機能数 3 未満の場合は全機能完了時のみ）。FR-5.9.2。 | 直近3機能を中心 |
| `feature:<機能名>` | 機能ループ F6.5（機能単位開発モード起動時、およびシステムループ S9 内の各機能ループでも適用）。`loop.yaml::feature_loop.persona_test_enabled=true`（既定）の場合に発動。FR-5.9.8。 | 当該新機能を主動線とし、既存連携動線も含める |
| `fix:<修正名>` | 修正ループ R6.5（修正対応モード起動時、およびペルソナテスト由来の改善要望対応時）。`loop.yaml::fix_loop.persona_test_enabled=true`（既定）の場合に発動。修正対応書の `severity` が `fix_loop.persona_test_severity_threshold` 以上のときのみ実施。FR-5.9.9。 | R2 の `impact_analysis` を入力に、修正対象 + 影響範囲動線。リグレッション観点を必須化 |

## 標準手順

1. **ペルソナ定義の確保（フォールバック含む）**:
   - `autodev/scripts/ensure_personas.sh` を実行。
   - exit 0 → 既存 `autodev/state/personas/personas.json` をそのまま再利用する。**既存 ID は書き換えない**（FR-5.9.1 改訂 / 世代管理ルール）。
   - exit 2 → `personas.json` が不在 or 最低人数不足。AI が次の入力からペルソナを定義し書き込んで再実行する。
       - scope=system: 要件定義書 + 全体設計書
       - scope=feature: 機能要件書 + 既存 `docs/設計/全体設計書.md` + （あれば）既存 `docs/設計/features/*.md`
       - scope=fix:   修正対応書 + R2 の `impact_analysis` + 影響範囲の `docs/設計/features/*.md`
     既定 3〜5 体。年齢/職業/IT リテラシー/スマートフォン利用文脈（通勤中・屋外・片手操作等）/優先度/制約を含む（FR-5.9.1）。
     **追記時は ID 末尾追加のみ**、既存 ID 書き換え禁止。
   - 不足分のみ追記したい場合も同様にレンジ内に補充する。

2. **実施番号の採番（全 scope 通し連番）**:
   - `state/persona_tests/*.json` を全件読み、`.test_number` の最大値 + 1 を `<実施番号>` とする（初回は 1）。
   - scope=system / feature / fix で同じディレクトリを共有するため、scope ごとに別連番を切らない（衝突防止 / B.7 採番ルール）。
   - 採番した番号は run_persona_tests.sh の第1引数、生成 flow のファイル名、attestation JSON の `test_number`、呼び出し元 attestation の `persona_test_ref` で同一値を使う。

3. **シナリオ設計（スコープ分岐）**:
   - 各ペルソナで「目的達成型 / 迷い・誤操作型 / エラーケース型」の3類を最低含む（FR-5.9.3）。
   - **Android 固有操作を最低1つ織り込む**（規約15 / 戻るボタン / 画面回転 / バックグラウンド退避→復帰 / プロセス kill 後の状態復元 / 機内モード / 権限拒否）。回転・機内モード等の端末操作は `run_adb.sh` で行い、手順をシナリオ記録に残す。
   - testTag 参照（座標タップ禁止）。各シナリオ要所で **Maestro flow に `takeScreenshot` を挿入**して改善要望抽出時の画面キャプチャを確実に得る（最終 `screencap` 任せにしない）。
   - **`scope=system`**: 直近3機能を中心に動線を組む。flow 命名: `maestro/persona/persona_<番号>_<ペルソナ>.yaml`。
   - **`scope=feature:<機能名>`**: 当該新機能を主動線とし、既存設計書の機能間関係から連携動線（起動→新機能 / 新機能→既存共通機能 等）を含める。flow 命名: `maestro/persona/persona_<番号>_feature_<機能名>_<ペルソナ>.yaml`。
   - **`scope=fix:<修正名>`**: R2 の `impact_analysis` の `files / screens / room_entities / dao / apis / permissions` を網羅。**リグレッション観点（影響範囲の既存機能が壊れていないこと）を必ず1類以上含める**。flow 命名: `maestro/persona/persona_<番号>_fix_<修正名>_<ペルソナ>.yaml`。

4. **実機実行**:
   - `autodev/scripts/run_persona_tests.sh <実施番号> --scope <スコープ>` でデバイス確保 + 最新ビルドインストール + flow 実行。
   - スクショ・logcat は `autodev/evidence/persona_tests/<番号>/` 直下（system）または `.../<番号>/<scope_dir>/`（feature_<名> / fix_<名>）に保存。
   - F6.5 → サブ fix-loop → 再 F6.5 のサイクル間でも同一デバイスを使い回す（再起動でフレーキー化しない）。サイクル間で `adb logcat -c` を毎回行い、新しい証跡が混ざらないようにする。

5. **改善要望の列挙**:
   - 各ペルソナ視点で「使いにくい点」「不足機能」「誤解しやすい表現」「Android 作法（戻る・回転・通知）への違反」を列挙。
   - **UI 観点も同時に吸収する**（システムループでは S11 `autodev-ui-polish` が別途走るが、機能ループ F6.5 / 修正ループ R6.5 では S11 が走らないため、当該画面の視覚階層・コントラスト・タップ領域・ローディング/エラー表現・誤操作リカバリ等の所見もここで `severity` 付きで列挙する）。

6. **修正ファイル生成**:
   - 各改善要望を `autodev/inputs/修正対応/修正_<改善名>.md` として自動生成。
   - ファイル名規約:
     - scope=system: 既存どおり `修正_<改善名>.md`
     - scope=feature: `修正_persona_feature_<機能名>_<改善名>.md`
     - scope=fix: `修正_persona_fix_<修正名>_<改善名>.md`
   - フロントマター（または冒頭セクション）に `source_scope` / `source_target` / `severity` を必ず記載。

7. **修正ループ対応**:
   - 優先度順に [autodev-fix-loop](../autodev-fix-loop/SKILL.md) で順次対応。優先度ジレンマは最小限の質問。
   - **scope=system の場合**: 修正完了後は `loop.yaml::re_persona_after_fix`（既定 `minor_only`）に従い再ペルソナテスト要否を判定し、必要なら同じ番号でもう一度本 skill を起動（最大 `max_fix_cycles_per_persona_run` 回 / 既定 2）。
   - **scope=feature の場合**: `loop.yaml::feature_loop.persona_test_max_cycles`（既定 2）まで「修正→再ペルソナ」を繰り返す。**サブ fix-loop は F6.5 の中で消化し、F7 クローズ前に必ず完了させる**。`re_persona_after_fix` の方針（既定 minor_only）も流用する。
   - **scope=fix の場合**: `loop.yaml::fix_loop.persona_test_max_cycles`（既定 2）まで繰り返す。**サブ fix-loop は R6.5 の中で消化し、R7 クローズ前に必ず完了させる**。
   - 上限到達時は残った改善要望を `blocking_issues` に転記し、人手判断待ちで停止する（呼び出し側の機能/修正ループは `blocked=true` で停止）。

8. **記録**:
   - `autodev/state/persona_tests/<番号>.json` に次を記録（B.7 拡張スキーマ）:
     - `scope`: `system` / `feature` / `fix`
     - `target`: 機能名 or 修正名（system のときは省略可）
     - `triggered_from`: `S7` / `S9` / `F6.5` / `R6.5`
     - `executed_at` / `target_features` or `target_impact` / `personas_run` / `scenarios` / `improvements` / `blocking_issues` / `result` / `cycles_used` / `cycles_max`
   - **同時に**呼び出し元の state を同期する:
     - system: `autodev/state/loops/system.json::persona_test_plan.schedule[]` 内の該当 `run_id` の `status` を `completed` に更新し、`executed_at`・`result` も併記。
     - feature: 当該機能の attestation `autodev/state/attestations/<機能名>.json` に `persona_test_ref: <番号>` を追加。
     - fix: 当該修正の attestation `autodev/state/attestations/<修正名>.json` に `persona_test_ref: <番号>` を追加。
   - PostToolUse hook が `autodev/開発進捗状況.md` を自動再生成（FR-5.6.7）。

## 省略禁止の不変条件（CLAUDE_MAIN.md 規約15）

- **ペルソナテストは正規フェーズである**。S7 で立てた計画（`system.json::persona_test_plan.schedule[]`）も、F6.5 / R6.5 も**全件実施**する。
- 「時間制約」「コンテキスト圧迫」「機能が単純だから不要」「スコープ調整」「後続作業として」等を理由とした省略は **すべて規約違反**。
- **設定 OFF は省略ではない**: `loop.yaml::<scope>_loop.persona_test_enabled=false` での無効化は明示的な OFF（規約15 のホワイトリスト）。AI 判断による省略との違いを `check_no_skip_excuses.sh` で区別する。
- 実施が完全に不可能な場合の正規ルート:
  1. `set_current.sh <mode> "<対象>" <phase> "" "persona_test_run_<N>" true "<理由>"` で人手介入待ち停止。
  2. blocked_reason に「なぜ今ペルソナテストを実施できないか」を具体的に記述する（「時間が足りない」は不可。例: 「Maestro セットアップ不能 (詳細: …)」「ペルソナ N の権限拒否シナリオがエミュレータで再現不能」等）。
- システム完了ゲート `check_system_completion.sh` は `persona_test_plan.schedule[].status` がすべて `completed` でないと PASS しない。未実施を残したまま「✅ システム完了」を宣言することは構造的に不可能。

## 完了条件

- 全ペルソナ × 全シナリオ実行完了。
- 改善要望リスト出力 / サブ修正ループ全完了（または `blocking_issues` に集約）。
- `autodev/state/persona_tests/<番号>.json::result == "completed"`。
- scope=system: `system.json::persona_test_plan.schedule[].status` が `completed` に同期。
- scope=feature / fix: 呼び出し元 attestation に `persona_test_ref` を併記。
- `autodev/scripts/check_no_skip_excuses.sh` PASS。

## 失敗時の挙動

- シナリオ flow の fail は改善要望（issue）として記録し、修正ループ対象にする。
- `persona_test_max_cycles` / `max_fix_cycles_per_persona_run` 超過時は残課題を `blocking_issues` に転記し、呼び出し元ループに `blocked=true` で返す。
- 環境的に実施不能（デバイス未確保・Maestro 不能 等）は `blocked=true` で停止し、ユーザーの介入を待つ。**「実施しなかった」「省略した」と書いて完了状態に進めることは禁止**。

## 関連参照

- [autodev-fix-loop](../autodev-fix-loop/SKILL.md) / [autodev-device-verify](../autodev-device-verify/SKILL.md)
- [autodev-feature-loop](../autodev-feature-loop/SKILL.md)（F6.5 から発動）
- スクリプト: `ensure_personas.sh` / `run_persona_tests.sh`（`--scope system|feature:<名>|fix:<名>`）/ `check_persona_test_evidence.sh`
- 詳細仕様: 要件定義書 FR-5.9 / 9.2(S7,S9) / 9.3(F6.5) / 9.4(R6.5)
