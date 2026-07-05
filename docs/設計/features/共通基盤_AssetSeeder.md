# 共通基盤_AssetSeeder（プレースホルダーアセット生成 + 初回シード）

## 機能概要

開発初期（S1 Q5）はプレースホルダーアセットでバンドルする。本機能は `assets/image/character/{id}/{variant}.webp` 35 枚、
ボイス・BGM・SE の `.ogg` を Gradle ビルド時に Kotlin スクリプトで自動生成し、初回起動時に `CharacterEntity` × 5 と
`CharacterImageEntity` × 35 を Room にシードする。

## 画面要素

なし（ビルド時生成 + 起動時シード）。

## ユーザー操作

なし。

## エラーケース

- アセットファイル欠落: ログ警告のみで進行（要件 §機能: キャラクターボイス・BGM・SE 再生 のエラーケースに一致）。
- DB シード失敗: 既存データがあれば再シードしない（INSERT OR IGNORE）。

## データモデル

`CharacterEntity` 5 行（hina / airi / yuki / mio / rin）と、それぞれに対する `CharacterImageEntity` 7 行（variant: normal / joy / anger / sad / chain / bigChain / lose）を生成。

```kotlin
val CHARACTERS = listOf(
  Character("hina", "ひな", "spk_01"),
  Character("airi", "あいり", "spk_02"),
  Character("yuki", "ゆき", "spk_03"),
  Character("mio",  "みお",  "spk_04"),
  Character("rin",  "りん",  "spk_05"),
)
```

## 受け入れ条件

- Given: アプリ初回起動完了
- When: `CharacterRepository.list().first()` を呼ぶ
- Then: 6 キャラ + 60 立ち絵レコードが返り、各 `assetPath` が `assets/image/character/<id>/<variant>.webp` を指し、ファイルが存在する。

## testTag 一覧

該当なし。
