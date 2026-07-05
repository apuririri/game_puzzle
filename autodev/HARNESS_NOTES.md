# HARNESS_NOTES（ハーネス棚卸しメモ）

ハーネス（環境ゲート・検証層・同期設計書・除外設定・各種規約・hooks/skills 仕様）の
存在理由と動作確認日を記録する。Claude Code 本体の更新後、および 3〜6ヶ月毎に棚卸しする（NFR-6.4.2）。

## DRI（説明責任者 / NFR-6.4.3）

- 氏名: （個人開発の場合は本人名を記入）
- 推奨 Claude / Claude Code バージョン: （運用開始時に記入）

## hooks の存在理由（FR-5.15.6）

| hook | 存在理由 | 直近動作確認日 |
|---|---|---|
| SessionStart | 冪等再開時に前回進捗を即把握させる | (雛形生成時) |
| UserPromptSubmit | 起動モード判定と入力形式チェックの自動化 | (雛形生成時) |
| PreToolUse(Bash) | 素コマンド実行（gradle/adb/maestro 直叩き・環境迂回）の機械禁止 | (雛形生成時) |
| PostToolUse(Edit\|Write) | 進捗.md 同期漏れ防止 + 言い訳語検出 + システム完了ゲート即時実行 | 2026-06-12 |
| PostToolUse(Bash) | コミット後の軽量ゲート自動実行 | (雛形生成時) |

## 完了強制ゲート（CLAUDE_MAIN.md 規約 12〜15）

| ゲート | 存在理由 | 直近動作確認日 |
|---|---|---|
| `check_no_skip_excuses.sh` | 「時間制約」「後続作業」「将来対応」「省略しました」等の言い訳語が進捗.md/state/attestation に混入することを機械検出。AI がフェーズ・ステップを自己判断スキップする運用ドリフトを構造的に防止（規約14）。 | 2026-06-12 |
| `check_system_completion.sh` | システムループ S12 完了宣言の事前ゲート9項目（features 全 done / attestation 揃い / persona_test_plan 全 completed / UI 層タスク存在 / 顧客向けドキュメント3種 / S10 スモーク証跡 / 言い訳語 PASS 等）。`set_current.sh` で mode を空にする操作と PostToolUse hook で多層強制（規約13）。 | 2026-06-12 |

## 回避策（workaround）の追加履歴

新たな回避策を追加したら、理由・対象事故クラス・恒久策の計画をここに記録する（恒久策と対症療法の誤認防止）。

| 日付 | 回避策 | 理由 | 恒久策の計画 |
|---|---|---|---|
| 2026-06-12 | CLAUDE_MAIN.md 絶対規約 12〜15 + check_no_skip_excuses.sh / check_system_completion.sh / set_current.sh ガード / PostToolUse hook 補強 | 観測事案: AI エージェントが「時間制約のためペルソナテスト未実施」「UI 開発は後続作業」とフェーズを勝手にスキップしてシステムループを打ち切る事象（中核思想7「ペルソナ視点必須化」/ FR-5.9.2 / FR-5.12.x の運用ドリフト）。テキスト規約のみの強制ではドリフトを防げないと判明したため、機械ゲートで多層防御。 | 機械ゲートが恒久策。3〜6ヶ月後に運用ログから誤検出率・バイパス頻度を棚卸しし、必要なら検出パターンを調整。 |

## AUTODEV_DISABLE_HOOKS の使用履歴（FR-5.15.5）

| 日付 | 使用者 | 理由 | 影響範囲 |
|---|---|---|---|
| - | - | - | - |

## AUTODEV_FORCE_COMPLETE の使用履歴（規約13 のバイパス）

`AUTODEV_FORCE_COMPLETE=1` は `check_system_completion.sh` を強制バイパスして `set_current.sh` で mode を空に遷移させる緊急用エスケープハッチ。使用時は必ず以下を記録する。

| 日付 | 使用者 | 理由 | 残存リスク |
|---|---|---|---|
| - | - | - | - |
