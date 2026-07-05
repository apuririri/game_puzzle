---
name: autodev-cleanup
description: 「不要データを洗い替えしてください」「クリーンアップ」等の指示で発動。長期運用で蓄積した autodev/ の証跡・ログ・履歴・解決済み修正入力を、要約を CHANGELOG/変更履歴に永続化した上でアーカイブ退避し、retention.yaml に従って prune する標準手順。--full-reset で運用履歴をクリーンスレート化。
required_doc_version: "5.2"
---

<!-- version: 1.0 -->

# autodev-cleanup skill

## 適用条件

- 「不要データを洗い替え」「蓄積データのクリーンアップ」等の指示。

## 標準手順

1. **要約を永続化（先に必ず）**：洗い替えで消える詳細のうち重要なものを `CHANGELOG.md`（リリース単位）と `docs/変更履歴.md`（実施ログ要約）へ追記。これで証跡を消しても監査性が残る。
2. **対象提示（dry-run）**：`autodev/scripts/cleanup.sh`（引数なし）で retention.yaml に基づく対象を提示。`--full-reset` 付きで全運用履歴を対象に。
3. **承認確認**：削除を伴うため、対象をユーザーに提示し合意を得る。
4. **実行**：`cleanup.sh --apply`（または `--full-reset --apply`）。`autodev/archive/cleanup_<ts>.tar.gz` にアーカイブ退避してから prune。
5. **後処理**：進捗.md 再生成、必要なら `autodev/archive/` を外部へ退避。

## 安全策（不変）

- `app/ maestro/ docs/設計/ CHANGELOG.md docs/変更履歴.md personas` は**絶対に触らない**。
- 進行中ループ（未完了の system.json/loops）は保持。
- 削除前に必ずアーカイブ。`--apply` 無しは提案のみ。
- `autodev/evidence/_archived/` 配下（案7 / critical evidence）は **prune 対象から自動除外**される（無期限保持）。各機能ループ F7 / 修正ループ R7 で `archive_critical_evidence.sh` が attestation の screenshots をここへコピー済み。

## 完了条件

- 要約が CHANGELOG/変更履歴に残っている／対象がアーカイブ済み／prune 完了／進捗.md 同期。

## 関連参照

- 設定: `autodev/config/retention.yaml`
- スクリプト: `autodev/scripts/cleanup.sh`
- 詳細仕様: `autodev/docs/本番運用フェイズ補足.md`（データライフサイクル章）
