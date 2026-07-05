# 機能要件: 共通基盤_AppDatabase

> S5 機能リスト補完で導出された基盤機能。要件定義書 §5 のデータモデルを Room スキーマとして実装するインフラ層。

## 機能概要

要件定義書 §5 に列挙された全 Entity（CharacterEntity / CharacterImageEntity / HighScoreEntity / StoryProgressEntity / SaveSlotEntity / AutoSaveEntity）と対応 Dao を Room データベース `app_database` として v1 で一括導入する。

## 画面要素

なし（インフラ層。UI を持たない）。

## ユーザー操作

なし。

## エラーケース

- DB 破損: Room の standard error がスローされ、呼び出し側で例外として補足できること
- Migration 必須化: v2 以降は Migration クラス + MigrationTest が必須

## データモデル

要件定義書 §5 を完全反映:
- CharacterEntity, CharacterImageEntity, HighScoreEntity, StoryProgressEntity, SaveSlotEntity, AutoSaveEntity

## 受け入れ条件

- Given: アプリ初回起動
- When: AppDatabase.getInstance(context) を呼ぶ
- Then: 6 つのテーブル + Memo 雛形テーブル（merge 必要）が作成され、`app/schemas/com.example.myapp.data.local.AppDatabase/1.json` が出力される
