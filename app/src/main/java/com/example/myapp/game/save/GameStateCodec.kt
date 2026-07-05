package com.example.myapp.game.save

import com.example.myapp.domain.game.Cell
import com.example.myapp.domain.game.CellColor
import com.example.myapp.domain.game.ChainEngine
import com.example.myapp.domain.game.GameField
import com.example.myapp.domain.game.Pair2
import com.example.myapp.domain.game.StepResult
import org.json.JSONArray
import org.json.JSONObject

/**
 * StepResult ↔ JSON 変換ユーティリティ。SaveLoadManager と PlayViewModel が使用。
 * 設計書: docs/設計/features/共通基盤_SaveLoadManager.md / セーブ_ロード.md
 *
 * 直列化形式:
 *  - field: 各列 [Int, Int, ...] （null は -1）
 *  - pair : {pv:Int, ch:Int, rot:Int, c:Int, r:Int}
 *  - CellColor は ordinal (0-5) で表現
 */
object GameStateCodec {

    fun encodeField(field: GameField): String {
        val arr = JSONArray()
        for (col in field.cells) {
            val colArr = JSONArray()
            for (cell in col) {
                colArr.put(cell?.color?.ordinal ?: -1)
            }
            arr.put(colArr)
        }
        return arr.toString()
    }

    fun decodeField(json: String): GameField {
        val arr = JSONArray(json)
        val cells = List(GameField.COLS) { c ->
            val colArr = arr.getJSONArray(c)
            List(GameField.ROWS) { r ->
                val ord = colArr.getInt(r)
                if (ord < 0) null else Cell(CellColor.values()[ord])
            }
        }
        return GameField(cells)
    }

    fun encodePair(p: Pair2): String = JSONObject().apply {
        put("pv", p.pivot.color.ordinal)
        put("ch", p.child.color.ordinal)
        put("rot", p.rotation)
        put("c", p.col)
        put("r", p.row)
    }.toString()

    fun decodePair(json: String): Pair2 {
        val o = JSONObject(json)
        return Pair2(
            pivot = Cell(CellColor.values()[o.getInt("pv")]),
            child = Cell(CellColor.values()[o.getInt("ch")]),
            rotation = o.getInt("rot"),
            col = o.getInt("c"),
            row = o.getInt("r"),
        )
    }

    /** StepResult 全体 → GameSnapshot に変換。 */
    fun toSnapshot(state: StepResult, mode: String, maxChain: Int, elapsedMs: Long): GameSnapshot {
        return GameSnapshot(
            mode = mode,
            fieldJson = encodeField(state.field),
            currentPair = state.current?.let { encodePair(it) },
            nextPair = encodePair(state.next),
            nextNextPair = encodePair(state.next2),
            score = state.score,
            maxChain = maxChain,
            elapsedMs = elapsedMs,
        )
    }

    /** GameSnapshot → StepResult に復元。 */
    fun fromSnapshot(snap: GameSnapshot): StepResult {
        return StepResult(
            field = decodeField(snap.fieldJson),
            current = snap.currentPair?.let { decodePair(it) } ?: ChainEngine.newPair(1L),
            next = decodePair(snap.nextPair),
            next2 = decodePair(snap.nextNextPair),
            score = snap.score,
            chains = emptyList(),
            isGameOver = false,
        )
    }
}
