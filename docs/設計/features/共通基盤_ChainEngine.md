# 共通基盤_ChainEngine（ぷよ連鎖判定 純粋ロジック）

## 機能概要

6×14 フィールド上の落下ペアの操作（移動・回転・ハードドロップ・ソフトドロップ）と、着地後の連鎖判定（同色 3 つ以上の縦横連結を再帰消去）を担う純粋ロジック（Android API に依存しない）。
全プレイ画面（エンドレス / スコアアタック / ストーリー / CPU 対戦）が共有する。

## 画面要素

なし（描画は呼び出し側 Composable + ChainEffectRenderer の責務）。

## ユーザー操作

なし（入力は `step(input: GameInput)` 経由）。

## エラーケース

- 不正な入力（壁・既設置ブロックに移動できない）: 無視（false を返す）。
- 着地予測中に他スレッドからの状態書き換え: ImmutableSnapshot 設計のため発生しない（StateFlow + copy）。

## データモデル

```kotlin
enum class CellColor { RED, GREEN, BLUE, YELLOW, PURPLE, OJAMA }
data class Cell(val color: CellColor)
data class Pair2(val pivot: Cell, val child: Cell, val rotation: Int /*0,90,180,270*/, val col: Int, val row: Int)
data class GameField(val cells: List<List<Cell?>>) // 6 cols × 14 rows
sealed class GameInput { object Left;object Right;object RotateCw;object SoftDrop;object HardDrop;object Tick }
data class ChainEvent(val level: Int, val poppedCount: Int, val colors: List<CellColor>)
data class StepResult(val field: GameField, val current: Pair2?, val next: Pair2, val next2: Pair2, val score: Long, val chains: List<ChainEvent>, val isGameOver: Boolean)
```

- `step(state, input): StepResult` は冪等で 16ms 以内に完了。
- 連鎖イベントは `Flow<ChainEvent>` で外部に流す（演出トリガ）。
- スコア計算: `score += popped * 10 * chainLevel * chainLevel`（仮）

## 受け入れ条件

- Given: テストフィクスチャで「同色 3 つを縦に揃え、上に同色 3 つを横に揃えた状態」
- When: ChainEngine.step(_, HardDrop) で着地させる
- Then: `chains` に level=2 のイベントが含まれ、スコアが加算される（JUnit テスト `ChainEngineTest.shouldDetectTwoChainsRecursively` 通過）。

## testTag 一覧

該当なし。
