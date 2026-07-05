# 共通基盤_SaveLoadManager（オート＋手動セーブ）

## 機能概要

プレイ中の `GameField + Pair2 + Score + MaxChain + Mode` を `serializedGameState`（kotlinx.serialization JSON）に直列化し、
`AutoSaveEntity(id=0)` への上書き（オートセーブ）と `SaveSlotEntity(slotIndex=1..10)` への手動セーブを提供する。

## 画面要素

なし（共通機能。SaveSlotScreen が UI を提供する）。

## ユーザー操作

なし（呼び出し側から）。

## エラーケース

- スキーマ変更時: Room Migration を必須（要件のとおり）。
- セーブデータ破損: パース失敗時は当該レコードを破棄し、呼び出し側に null を返す（呼び出し側がダイアログ通知）。

## データモデル

```kotlin
@Serializable
data class GameSnapshot(
  val mode: String,
  val field: GameField,
  val currentPair: Pair2?,
  val nextPair: Pair2,
  val nextNextPair: Pair2,
  val score: Long,
  val maxChain: Int,
  val elapsedMs: Long,
)

class SaveLoadManager(autoDao: AutoSaveDao, slotDao: SaveSlotDao, settingsRepo: SettingsRepository) {
  suspend fun autoSave(snap: GameSnapshot)
  suspend fun loadAuto(): GameSnapshot?
  suspend fun saveSlot(index: Int, snap: GameSnapshot)
  suspend fun loadSlot(index: Int): GameSnapshot?
  suspend fun deleteSlot(index: Int)
  fun observeSlots(): Flow<List<SaveSlotEntity>>
}
```

## 受け入れ条件

- Given: エンドレスモード中、ぷよ着地ごとに autoSave が呼ばれる
- When: アプリ kill → 再起動 → `loadAuto()`
- Then: 直前の `GameSnapshot` が復元され、プレイ画面に同じ状態で復帰できる（Compose UI Test で snapshot 比較）。

## testTag 一覧

該当なし（呼び出し側 SaveSlotScreen / 一時停止メニュー側に持たせる）。
