package com.example.myapp.domain.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 設計書: docs/設計/features/共通基盤_ChainEngine.md 受け入れ条件
 */
class ChainEngineTest {

    @Test
    fun initialState_hasCurrentAndNexts() {
        val s = ChainEngine.initialState(seed = 1L)
        assertNotNull(s.current)
        assertNotNull(s.next)
        assertNotNull(s.next2)
        assertFalse(s.isGameOver)
        assertEquals(0L, s.score)
    }

    @Test
    fun findPops_returnsGroupOf3SameColorAdjacent() {
        // 同色 3 つを横一列に並べたフィールド
        val color = Cell(CellColor.RED)
        val emptyCol = List<Cell?>(14) { null }
        val cols = listOf(
            (listOf<Cell?>(color) + List<Cell?>(13) { null }),
            (listOf<Cell?>(color) + List<Cell?>(13) { null }),
            (listOf<Cell?>(color) + List<Cell?>(13) { null }),
            emptyCol, emptyCol, emptyCol,
        )
        val field = GameField(cols)
        val groups = ChainEngine.findPops(field)
        assertEquals(1, groups.size)
        assertEquals(3, groups.first().size)
    }

    @Test
    fun findPops_ignoresOjama() {
        val ojama = Cell(CellColor.OJAMA)
        val emptyCol = List<Cell?>(14) { null }
        val cols = listOf(
            (listOf<Cell?>(ojama) + List<Cell?>(13) { null }),
            (listOf<Cell?>(ojama) + List<Cell?>(13) { null }),
            (listOf<Cell?>(ojama) + List<Cell?>(13) { null }),
            emptyCol, emptyCol, emptyCol,
        )
        val field = GameField(cols)
        val groups = ChainEngine.findPops(field)
        assertTrue(groups.isEmpty())
    }

    @Test
    fun applyGravity_dropsCellsToBottom() {
        val red = Cell(CellColor.RED)
        val emptyCol = List<Cell?>(14) { null }
        val cols = listOf(
            // 列 0: 行5にだけ赤、それ以外 null → 行0 に降りるはず
            (List<Cell?>(5) { null } + listOf<Cell?>(red) + List<Cell?>(8) { null }),
            emptyCol, emptyCol, emptyCol, emptyCol, emptyCol,
        )
        val field = GameField(cols)
        val after = ChainEngine.applyGravity(field)
        assertEquals(red, after.cell(0, 0))
        assertEquals(null, after.cell(0, 5))
    }

    @Test
    fun landAndChain_detectsSingleChainOnHardDrop() {
        // 同色 2 つを底に並べ、HardDrop で 3 つ目を着地させると消去発生
        val red = Cell(CellColor.RED)
        val emptyCol = List<Cell?>(14) { null }
        val cols = listOf(
            (listOf<Cell?>(red) + List<Cell?>(13) { null }),
            (listOf<Cell?>(red) + List<Cell?>(13) { null }),
            emptyCol, emptyCol, emptyCol, emptyCol,
        )
        val field = GameField(cols)
        val current = Pair2(pivot = red, child = Cell(CellColor.BLUE), rotation = 0, col = 2, row = 12)
        val state = StepResult(field, current, ChainEngine.newPair(10), ChainEngine.newPair(11), 0, emptyList(), false)
        val result = ChainEngine.step(state, GameInput.HardDrop)
        assertTrue("3連結なら chains は 1 段以上", result.chains.isNotEmpty())
        assertEquals(1, result.chains.first().level)
    }

    @Test
    fun canPlace_rejectsOutOfBounds() {
        val pair = Pair2(pivot = Cell(CellColor.RED), child = Cell(CellColor.BLUE), rotation = 90, col = 5, row = 12)
        assertFalse(ChainEngine.canPlace(GameField.empty(), pair))
    }
}
