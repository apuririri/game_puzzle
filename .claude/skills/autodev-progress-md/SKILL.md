---
name: autodev-progress-md
description: 通常は PostToolUse hook が自動実行するため手動発動は不要だが、hook 失敗時の手動リカバリ・冪等再開時の整合確認で、autodev/開発進捗状況.md を state から再生成・同期確認するための補助手順。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-progress-md skill

## 適用条件

- PostToolUse hook が進捗.md 再生成に失敗した場合の手動リカバリ。
- 冪等再開（セッション中断後）に進捗.md と state の整合を確認したいとき。

## 標準手順

1. **再生成**: `autodev/scripts/update_progress_md.sh` を実行。state（loops/tasks/attestations/persona_tests）から人間可読の進捗.md を生成する。
2. **同期確認**: `autodev/scripts/check_progress_md_sync.sh` を実行。state の最新更新より進捗.md が古ければ fail。
3. **可読性確認**: 進捗.md が 1行サマリ・機能リスト（✅/🔄/⏳）・次アクション 1〜3行を含むことを確認（FR-5.6.8）。
4. **肥大化対応**: 500 行を超えそうなら旧版を `autodev/state/history/progress_<ts>.md` へ退避。

## 完了条件

- `check_progress_md_sync.sh` PASS / 進捗.md が最新 state を反映。

## 失敗時の挙動

- jq 不在・state 破損時は、最低限ヘッダ + 一行サマリ + 次アクションだけでも生成して停止せず続行。

## 関連参照

- 自動実行 hook: `autodev/hooks/claude/on_post_tool_use_edit_write.sh`
- 詳細仕様: 要件定義書 FR-5.6.7 / FR-5.6.8 / 付録D
