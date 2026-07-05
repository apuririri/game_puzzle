package com.example.myapp.game.save

import com.example.myapp.data.local.dao.AutoSaveDao
import com.example.myapp.data.local.dao.SaveSlotDao
import com.example.myapp.data.local.entity.AutoSaveEntity
import com.example.myapp.data.local.entity.SaveSlotEntity
import kotlinx.coroutines.flow.Flow
import org.json.JSONArray
import org.json.JSONObject

/**
 * オート + 手動セーブのマネージャ。GameSnapshot を JSON に直列化して Room に保存。
 * 設計書: docs/設計/features/共通基盤_SaveLoadManager.md
 *
 * 注: kotlinx.serialization 依存を増やさないため、org.json を使う最小実装。
 */
data class GameSnapshot(
    val mode: String,
    val fieldJson: String,    // ChainEngine.GameField.cells を JSON 化（呼び出し側で encode/decode）
    val currentPair: String?, // Pair2 の JSON
    val nextPair: String,
    val nextNextPair: String,
    val score: Long,
    val maxChain: Int,
    val elapsedMs: Long,
) {
    fun toJsonString(): String = JSONObject().apply {
        put("mode", mode)
        put("fieldJson", fieldJson)
        put("currentPair", currentPair ?: JSONObject.NULL)
        put("nextPair", nextPair)
        put("nextNextPair", nextNextPair)
        put("score", score)
        put("maxChain", maxChain)
        put("elapsedMs", elapsedMs)
    }.toString()

    companion object {
        fun fromJsonString(s: String): GameSnapshot {
            val o = JSONObject(s)
            return GameSnapshot(
                mode = o.getString("mode"),
                fieldJson = o.getString("fieldJson"),
                currentPair = if (o.isNull("currentPair")) null else o.getString("currentPair"),
                nextPair = o.getString("nextPair"),
                nextNextPair = o.getString("nextNextPair"),
                score = o.getLong("score"),
                maxChain = o.getInt("maxChain"),
                elapsedMs = o.getLong("elapsedMs"),
            )
        }
    }
}

class SaveLoadManager(
    private val autoDao: AutoSaveDao,
    private val slotDao: SaveSlotDao,
) {
    suspend fun autoSave(snap: GameSnapshot) {
        autoDao.upsert(
            AutoSaveEntity(
                id = 0,
                mode = snap.mode,
                serializedGameState = snap.toJsonString(),
                savedAt = System.currentTimeMillis(),
            )
        )
    }

    suspend fun loadAuto(): GameSnapshot? {
        val row = autoDao.get() ?: return null
        val json = row.serializedGameState ?: return null
        return try { GameSnapshot.fromJsonString(json) } catch (e: Exception) { null }
    }

    suspend fun clearAuto() = autoDao.clear()

    suspend fun saveSlot(index: Int, snap: GameSnapshot) {
        slotDao.upsert(
            SaveSlotEntity(
                slotIndex = index,
                mode = snap.mode,
                serializedGameState = snap.toJsonString(),
                score = snap.score,
                savedAt = System.currentTimeMillis(),
            )
        )
    }

    suspend fun loadSlot(index: Int): GameSnapshot? {
        val row = slotDao.get(index) ?: return null
        return try { GameSnapshot.fromJsonString(row.serializedGameState) } catch (e: Exception) { null }
    }

    suspend fun deleteSlot(index: Int) = slotDao.deleteByIndex(index)

    fun observeSlots(): Flow<List<SaveSlotEntity>> = slotDao.observeAll()
}
