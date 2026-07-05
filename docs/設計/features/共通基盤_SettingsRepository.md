# 共通基盤_SettingsRepository（DataStore）

## 機能概要

`androidx.datastore.preferences` 上に、要件 §5 DataStore キー全 10 個を管理するリポジトリ。
全画面から `Flow<AppSettings>` で購読可能とする。書き込み失敗時はスナックバー通知を呼び出し側に依頼する。

## 画面要素

なし（バックグラウンド）。

## ユーザー操作

なし（設定画面 / キャラクター選択 / チュートリアル等から間接的に呼ばれる）。

## エラーケース

- DataStore 書き込み失敗（IOException）: 例外を呼び出し側に流し、`SettingsRepository.update*` の戻り値で失敗を伝える。
- DataStore corrupt: `corruptionHandler { ReplaceFileCorruptionHandler { emptyPreferences() } }` で既定値復元（DataStore 標準。fallback ではなく仕様）。

## データモデル

要件 §5 全キーを実装。

```kotlin
data class AppSettings(
  val difficulty: Difficulty = Difficulty.Normal,
  val bgmEnabled: Boolean = true,
  val bgmVolume: Float = 0.8f,
  val seEnabled: Boolean = true,
  val seVolume: Float = 1.0f,
  val voiceEnabled: Boolean = true,
  val voiceVolume: Float = 1.0f,
  val chainClipEnabled: Boolean = true,
  val selectedCharacterId: String = "hina",
  val tutorialLastViewedPage: Int = 0,
)
enum class Difficulty { Easy, Normal, Hard, Expert }
```

## 受け入れ条件

- Given: 初回起動
- When: `SettingsRepository.observe().first()` を呼ぶ
- Then: 上記既定値の `AppSettings` が返り、`update*` で永続化後に再 observe すると新値が返る。

## testTag 一覧

該当なし。
