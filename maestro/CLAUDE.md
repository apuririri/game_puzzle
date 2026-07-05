# maestro/ 規約（E2E flow）

このディレクトリは顧客提供物の E2E テスト（Maestro YAML flow）。

## 必ず守る

1. **ラッパー経由実行**: 素の `maestro` は禁止。`autodev/scripts/test_maestro.sh <flow> [対象名]`（または `run_maestro.sh`）を使う。
2. **testTag 参照**: 要素は `id: "<testTag>"`（resource-id）で参照する。**座標タップ（point:）は禁止**。
   testTag 一覧は `docs/設計/screen_flow.md` / `docs/設計/features/<機能名>.md` を参照。
   **inputText は Android では ASCII のみ対応**（Maestro の既知制限）。日本語入力の検証が必要な場合は
   Compose UI Test（performTextInput はユニコード可）側で行う。
3. **appId**: `loop.yaml::application_id` と一致させる。
4. **構成**:
   - `smoke.yaml` — 起動スモーク（デプロイ後スモーク・S10 でも使用。常に PASS を維持）
   - `<機能名>.yaml` — 機能ごとの受け入れ条件 flow（F6 実機検証で使用）
   - `persona/persona_<番号>_<ペルソナ>.yaml` — システムループ用ペルソナテストシナリオ（scope=system / S7・S9）
   - `persona/persona_<番号>_feature_<機能名>_<ペルソナ>.yaml` — 機能ループ F6.5 用（scope=feature / FR-5.9.8）
   - `persona/persona_<番号>_fix_<修正名>_<ペルソナ>.yaml` — 修正ループ R6.5 用（scope=fix / FR-5.9.9）
5. **シナリオ3類型 + Android 固有操作**: 目的達成型 / 迷い・誤操作型 / エラーケース型 を意識して作成し、各実施で
   **Android 固有操作を最低1つ織り込む**（戻る・回転・バックグラウンド退避→復帰・プロセス kill 後の状態復元・
   機内モード・権限拒否）。端末操作は `run_adb.sh` と組み合わせる。
6. **flow 要所で takeScreenshot を取る**: 改善要望抽出（F6.5 / R6.5 / S7 / S9）のためには flow 終了時の
   final screenshot だけでなく、画面遷移や状態変化の要所で `takeScreenshot` を取り、UI 観点の評価ができる
   証跡を残す。
7. **証跡**: スクショは `takeScreenshot` で `autodev/evidence/screenshots/<対象名>/` または
   `autodev/evidence/persona_tests/<番号>/[feature_<名>|fix_<名>]/` へ。実行証跡は `test_maestro.sh` /
   `run_persona_tests.sh` が `autodev/evidence/maestro/` 配下に保存する。
8. **F6.5 / R6.5 のシナリオ範囲**:
   - F6.5（scope=feature）: 当該新機能を主動線とし、全体設計書から特定した既存連携動線（起動→新機能 /
     新機能→既存共通機能 等）も含める。
   - R6.5（scope=fix）: R2 の `impact_analysis`（files / screens / room_entities / dao / apis / permissions）
     を入力に、修正対象 + 影響範囲動線を中心にし、**リグレッション観点（影響範囲の既存機能が壊れていない）を
     必ず1類以上含める**。
