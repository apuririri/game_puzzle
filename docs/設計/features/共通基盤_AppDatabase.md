# 共通基盤_AppDatabase（Room スキーマ初期化）

## 機能概要

アプリ全体で共有する Room データベース（`app_database`）と全 Entity / Dao を初期化する共通基盤。
v1 で要件 §5 の全 6 Entity を一括導入し、`exportSchema=true` で `app/schemas/` に出力する。

## 画面要素

なし（バックグラウンドの基盤機能）。本機能は UI を持たない。

## ユーザー操作

なし。

## エラーケース

- DB ファイル破損（kotlinx.io 例外）: クラッシュさせず、`util/AppLogger.kt::DbLog` で error 出力 → アプリは fallback で空 DB を再生成する旨をログに残す（ユーザー UI 通知は呼び出し側責務）。
- マイグレーション失敗: `Room.databaseBuilder` の `addMigrations` で例外 → `fallbackToDestructiveMigration` は使わない（FR-5.3.3 fallback 禁止）。Migration 不在は schema 差分検出時にビルド時 fail とする。

## データモデル

要件 §5 全 6 Entity を実装する。

| Entity | 主キー | 主要カラム |
|---|---|---|
| `CharacterEntity` | id: String | displayName: String, voiceTone: String, unlocked: Boolean |
| `CharacterImageEntity` | id: String | characterId: String (FK), variant: String, assetPath: String |
| `HighScoreEntity` | id: Long auto | mode: String, score: Long, maxChain: Int, characterId: String, playedAt: Long |
| `StoryProgressEntity` | id: String | clearedChapter: Int, updatedAt: Long |
| `SaveSlotEntity` | slotIndex: Int | mode: String, serializedGameState: String, score: Long, savedAt: Long |
| `AutoSaveEntity` | id: Int (=0) | mode: String?, serializedGameState: String?, savedAt: Long? |

Dao は機能別に `CharacterDao` / `HighScoreDao` / `StoryProgressDao` / `SaveSlotDao` / `AutoSaveDao` を切る。

## 受け入れ条件

- Given: アプリ初回起動
- When: `AppDatabase.getInstance(context)` を呼び出す
- Then: 6 つのテーブルが作成され、`app/schemas/com.example.myapp.data.local.AppDatabase/1.json` が出力されており、空のテーブルから SELECT が成功する。

## testTag 一覧

該当なし（UI を持たない基盤機能）。
