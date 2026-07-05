# 共通基盤_CharacterRepository

## 機能概要

`CharacterEntity` と `CharacterImageEntity` をまとめてドメインモデル `Character`（id, displayName, voiceTone, images: Map<Variant, AssetPath>）で公開するリポジトリ。
キャラクター選択画面・タイトル・各プレイ画面・連鎖演出からキャラ立ち絵 7 パターンを取得するために使う。

## 画面要素

なし。

## ユーザー操作

なし。

## エラーケース

- 立ち絵画像 decode 失敗（FileNotFoundException 等）: `null` を返し、UI 側でプレースホルダーを表示する責務とする（要件: キャラクター選択 §エラーケース）。

## データモデル

- `Variant` = 列挙: normal / joy / anger / sad / chain / bigChain / lose
- `Character(id, displayName, voiceTone, unlocked, images: Map<Variant, String>)`
- `Flow<List<Character>>` を公開（`CharacterDao.observeAll()` JOIN）

## 受け入れ条件

- Given: 初回起動完了
- When: `CharacterRepository.observe().first()` を呼ぶ
- Then: 6 キャラがそれぞれ 10 variant の `assetPath` を持って返る。

## testTag 一覧

該当なし。
