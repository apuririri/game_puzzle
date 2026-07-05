package com.example.myapp.domain.game

import kotlin.math.abs

/**
 * ぷよ連鎖判定の純粋ロジック。Android API に依存しない。
 * 設計書: docs/設計/features/共通基盤_ChainEngine.md
 *
 * フィールド: 6 列 × 14 行（行 0 が最下段、行 13 が最上段で「窒息」検出ライン）。
 * 配色: 5 色 + おじゃま。
 */
enum class CellColor { RED, GREEN, BLUE, YELLOW, PURPLE, OJAMA }

data class Cell(val color: CellColor)

/**
 * 落下中ペア。pivot=軸ぷよ、child=連結相手。rotation で child の相対位置:
 *   0=上(row+1)、90=右(col+1)、180=下(row-1)、270=左(col-1)
 */
data class Pair2(
    val pivot: Cell,
    val child: Cell,
    val rotation: Int = 0,
    val col: Int = 2,
    val row: Int = 12,
) {
    fun childCol(): Int = when (rotation) { 90 -> col + 1; 270 -> col - 1; else -> col }
    fun childRow(): Int = when (rotation) { 0 -> row + 1; 180 -> row - 1; else -> row }
}

data class GameField(val cells: List<List<Cell?>>) {
    companion object {
        const val COLS = 6
        const val ROWS = 14
        fun empty(): GameField = GameField(List(COLS) { List(ROWS) { null } })
    }

    fun cell(col: Int, row: Int): Cell? = cells.getOrNull(col)?.getOrNull(row)

    fun set(col: Int, row: Int, value: Cell?): GameField {
        val newCells = cells.mapIndexed { c, column ->
            if (c == col) column.mapIndexed { r, cell -> if (r == row) value else cell } else column
        }
        return GameField(newCells)
    }
}

sealed class GameInput {
    object Left : GameInput()
    object Right : GameInput()
    object RotateCw : GameInput()
    object SoftDrop : GameInput()
    object HardDrop : GameInput()
    object Tick : GameInput()
}

data class ChainEvent(
    val level: Int,
    val poppedCount: Int,
    val colors: List<CellColor>,
    /** 消去対象のセル座標（UI 側で消去アニメを描画するために必要）。 */
    val cellsToPop: List<Pair<Int, Int>> = emptyList(),
)

data class StepResult(
    val field: GameField,
    val current: Pair2?,
    val next: Pair2,
    val next2: Pair2,
    val score: Long,
    val chains: List<ChainEvent>,
    val isGameOver: Boolean,
)

/**
 * 純粋ロジック。step は冪等で I/O なし。連鎖を全段検出し chains[] に流す。
 */
object ChainEngine {

    private const val MIN_POP = 3

    fun newPair(seed: Long): Pair2 {
        val colors = listOf(CellColor.RED, CellColor.GREEN, CellColor.BLUE, CellColor.YELLOW, CellColor.PURPLE)
        val a = colors[((seed * 2654435761L) ushr 32).toInt().let { abs(it) } % colors.size]
        val b = colors[((seed * 40503L) ushr 16).toInt().let { abs(it) } % colors.size]
        return Pair2(pivot = Cell(a), child = Cell(b), rotation = 0, col = 2, row = 12)
    }

    fun step(
        state: StepResult,
        input: GameInput,
        seedForNext: Long = state.score,
    ): StepResult {
        val current = state.current ?: return state
        var field = state.field
        var pair = current
        var score = state.score
        var chains = emptyList<ChainEvent>()
        var isGameOver = state.isGameOver
        var newCurrent: Pair2? = pair
        var nextPair = state.next
        var next2Pair = state.next2

        when (input) {
            GameInput.Left -> if (canMove(field, pair, -1, 0)) pair = pair.copy(col = pair.col - 1)
            GameInput.Right -> if (canMove(field, pair, 1, 0)) pair = pair.copy(col = pair.col + 1)
            GameInput.RotateCw -> {
                val candidate = pair.copy(rotation = (pair.rotation + 90) % 360)
                if (canPlace(field, candidate)) pair = candidate
            }
            GameInput.SoftDrop -> if (canMove(field, pair, 0, -1)) pair = pair.copy(row = pair.row - 1)
            GameInput.HardDrop -> {
                while (canMove(field, pair, 0, -1)) pair = pair.copy(row = pair.row - 1)
                val (placed, popResults) = landAndChain(field, pair, score)
                field = placed.field
                score = placed.score + popResults.scoreDelta
                chains = popResults.chains
                newCurrent = nextPair
                nextPair = next2Pair
                next2Pair = newPair(seedForNext + 1)
                if (!canPlace(field, newCurrent)) {
                    isGameOver = true
                    newCurrent = null
                }
                return StepResult(field, newCurrent, nextPair, next2Pair, score, chains, isGameOver)
            }
            GameInput.Tick -> {
                if (canMove(field, pair, 0, -1)) {
                    pair = pair.copy(row = pair.row - 1)
                } else {
                    val (placed, popResults) = landAndChain(field, pair, score)
                    field = placed.field
                    score = placed.score + popResults.scoreDelta
                    chains = popResults.chains
                    newCurrent = nextPair
                    nextPair = next2Pair
                    next2Pair = newPair(seedForNext + 1)
                    if (!canPlace(field, newCurrent)) {
                        isGameOver = true
                        newCurrent = null
                    }
                    return StepResult(field, newCurrent, nextPair, next2Pair, score, chains, isGameOver)
                }
            }
        }
        newCurrent = pair
        return StepResult(field, newCurrent, nextPair, next2Pair, score, chains, isGameOver)
    }

    fun canMove(field: GameField, pair: Pair2, dc: Int, dr: Int): Boolean {
        val newPair = pair.copy(col = pair.col + dc, row = pair.row + dr)
        return canPlace(field, newPair)
    }

    fun canPlace(field: GameField, pair: Pair2): Boolean {
        if (pair.col < 0 || pair.col >= GameField.COLS) return false
        if (pair.row < 0 || pair.row >= GameField.ROWS) return false
        if (field.cell(pair.col, pair.row) != null) return false
        val cc = pair.childCol(); val cr = pair.childRow()
        if (cc < 0 || cc >= GameField.COLS) return false
        if (cr < 0 || cr >= GameField.ROWS) return false
        if (field.cell(cc, cr) != null) return false
        return true
    }

    data class PlacedState(val field: GameField, val score: Long)
    data class PopResults(val chains: List<ChainEvent>, val scoreDelta: Long)

    /**
     * 着地のみ実行（消去・連鎖はしない）。連鎖アニメを 1 段ずつ描画するための分割 API。
     * 戻り値の field は重力適用済み。pair が画面外に出る position は呼出側で防ぐ前提。
     */
    fun placeAndGravity(field: GameField, pair: Pair2): GameField {
        var f = field
            .set(pair.col, pair.row, pair.pivot)
            .set(pair.childCol(), pair.childRow(), pair.child)
        f = applyGravity(f)
        return f
    }

    /**
     * 現在の field と次の連鎖 level (1=最初の連鎖) を受け取り、1 段だけ消去 + 重力を行う。
     * 戻り値:
     *   - first: 消去対象セル座標と level の ChainEvent。null なら連鎖終了。
     *   - second: 重力適用後の field（連鎖発生時のみ更新。null なら入力 field と同一）。
     *   - third: scoreDelta（この段の加点）。
     * UI 層は first.cellsToPop に対してアニメを描画してから second の field を反映する。
     */
    fun popOneStep(field: GameField, level: Int): Triple<ChainEvent?, GameField, Long> {
        val popped = findPops(field)
        if (popped.isEmpty()) return Triple(null, field, 0L)
        val cellsToPop = popped.flatten().toSet()
        val colors = cellsToPop.map { (c, r) -> field.cell(c, r)!!.color }.distinct()
        val event = ChainEvent(
            level = level,
            poppedCount = cellsToPop.size,
            colors = colors,
            cellsToPop = cellsToPop.toList(),
        )
        var f = field
        for ((c, r) in cellsToPop) f = f.set(c, r, null)
        val ojamasToRemove = mutableSetOf<Pair<Int, Int>>()
        for ((c, r) in cellsToPop) {
            listOf(c - 1 to r, c + 1 to r, c to r - 1, c to r + 1).forEach { (oc, or) ->
                if (f.cell(oc, or)?.color == CellColor.OJAMA) ojamasToRemove += (oc to or)
            }
        }
        for ((c, r) in ojamasToRemove) f = f.set(c, r, null)
        f = applyGravity(f)
        val scoreDelta = cellsToPop.size.toLong() * 10L * level.toLong() * level.toLong()
        return Triple(event, f, scoreDelta)
    }

    fun landAndChain(field: GameField, pair: Pair2, score: Long): Pair<PlacedState, PopResults> {
        var newField = field
            .set(pair.col, pair.row, pair.pivot)
            .set(pair.childCol(), pair.childRow(), pair.child)
        newField = applyGravity(newField)
        val events = mutableListOf<ChainEvent>()
        var level = 0
        var totalDelta = 0L
        while (true) {
            val popped = findPops(newField)
            if (popped.isEmpty()) break
            level += 1
            val cellsToPop = popped.flatten().toSet()
            val colors = cellsToPop.map { (c, r) -> newField.cell(c, r)!!.color }
            events += ChainEvent(level = level, poppedCount = cellsToPop.size, colors = colors.distinct(), cellsToPop = cellsToPop.toList())
            // 消去
            var f2 = newField
            for ((c, r) in cellsToPop) f2 = f2.set(c, r, null)
            // 隣接おじゃまも 1 つ巻き込む
            val ojamasToRemove = mutableSetOf<Pair<Int, Int>>()
            for ((c, r) in cellsToPop) {
                listOf(c - 1 to r, c + 1 to r, c to r - 1, c to r + 1).forEach { (oc, or) ->
                    if (f2.cell(oc, or)?.color == CellColor.OJAMA) ojamasToRemove += (oc to or)
                }
            }
            for ((c, r) in ojamasToRemove) f2 = f2.set(c, r, null)
            f2 = applyGravity(f2)
            newField = f2
            totalDelta += cellsToPop.size.toLong() * 10L * level.toLong() * level.toLong()
        }
        return Pair(PlacedState(newField, score), PopResults(events, totalDelta))
    }

    fun applyGravity(field: GameField): GameField {
        val cols = field.cells.map { col ->
            val stack = col.filterNotNull()
            val padded = stack + List(GameField.ROWS - stack.size) { null }
            padded
        }
        return GameField(cols)
    }

    /**
     * 4 連結 (MIN_POP 以上) を探索（同色のみ。おじゃまは消去対象にならない）。
     * 戻り値: 各グループのセル座標リスト。
     */
    fun findPops(field: GameField): List<List<Pair<Int, Int>>> {
        val visited = Array(GameField.COLS) { BooleanArray(GameField.ROWS) }
        val groups = mutableListOf<List<Pair<Int, Int>>>()
        for (c in 0 until GameField.COLS) {
            for (r in 0 until GameField.ROWS) {
                if (visited[c][r]) continue
                val cell = field.cell(c, r) ?: continue
                if (cell.color == CellColor.OJAMA) continue
                val group = mutableListOf<Pair<Int, Int>>()
                val stack = ArrayDeque<Pair<Int, Int>>()
                stack.addLast(c to r)
                while (stack.isNotEmpty()) {
                    val (cc, rr) = stack.removeLast()
                    if (cc < 0 || cc >= GameField.COLS || rr < 0 || rr >= GameField.ROWS) continue
                    if (visited[cc][rr]) continue
                    val cell2 = field.cell(cc, rr) ?: continue
                    if (cell2.color != cell.color) continue
                    visited[cc][rr] = true
                    group += (cc to rr)
                    stack.addLast(cc + 1 to rr)
                    stack.addLast(cc - 1 to rr)
                    stack.addLast(cc to rr + 1)
                    stack.addLast(cc to rr - 1)
                }
                if (group.size >= MIN_POP) groups += group
            }
        }
        return groups
    }

    fun initialState(seed: Long = 1L): StepResult {
        val cur = newPair(seed)
        val nxt = newPair(seed + 1)
        val nxt2 = newPair(seed + 2)
        return StepResult(
            field = GameField.empty(),
            current = cur,
            next = nxt,
            next2 = nxt2,
            score = 0L,
            chains = emptyList(),
            isGameOver = false,
        )
    }
}
