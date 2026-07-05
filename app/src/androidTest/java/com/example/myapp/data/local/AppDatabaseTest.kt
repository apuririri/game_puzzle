package com.example.myapp.data.local

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.myapp.data.local.entity.AutoSaveEntity
import com.example.myapp.data.local.entity.CharacterEntity
import com.example.myapp.data.local.entity.CharacterImageEntity
import com.example.myapp.data.local.entity.HighScoreEntity
import com.example.myapp.data.local.entity.SaveSlotEntity
import com.example.myapp.data.local.entity.StoryProgressEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 設計書: docs/設計/features/共通基盤_AppDatabase.md 受け入れ条件
 * Given アプリ初回起動相当 → When getInstance 相当 → Then 全 7 テーブルが作成される。
 */
@RunWith(AndroidJUnit4::class)
class AppDatabaseTest {

    private lateinit var db: AppDatabase

    @Before
    fun setUp() {
        db = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java
        ).allowMainThreadQueries().build()
    }

    @After
    fun tearDown() {
        db.close()
    }

    @Test
    fun characterTable_insertAndQuery() = runTest {
        val rows = listOf(
            CharacterEntity("hina", "ひな", "spk_01"),
            CharacterEntity("airi", "あいり", "spk_02"),
        )
        db.characterDao().insertAll(rows)
        val observed = db.characterDao().observeAll().first()
        assertEquals(2, observed.size)
        // ORDER BY id でアルファベット順
        assertEquals(listOf("airi", "hina"), observed.map { it.id })
        assertEquals(2, db.characterDao().count())
    }

    @Test
    fun characterImageTable_insertAndQueryByCharacter() = runTest {
        db.characterDao().insertAll(listOf(CharacterEntity("hina", "ひな", "spk_01")))
        val images = listOf("normal", "joy", "anger", "sad", "chain", "bigChain", "lose")
            .map { CharacterImageEntity(id = "hina_$it", characterId = "hina", variant = it, assetPath = "image/character/hina/$it.webp") }
        db.characterDao().insertAllImages(images)
        val got = db.characterDao().imagesOf("hina")
        assertEquals(7, got.size)
    }

    @Test
    fun highScoreTop10_orderedByScoreDescThenPlayedAtAsc() = runTest {
        val dao = db.highScoreDao()
        // 12 件入れて上位 10 だけ返ること、同点は playedAt 古い順を確認
        dao.insert(HighScoreEntity(mode = "endless", score = 1000, maxChain = 5, characterId = "hina", playedAt = 1000))
        dao.insert(HighScoreEntity(mode = "endless", score = 1000, maxChain = 5, characterId = "airi", playedAt = 500)) // 同点、古い → 上位
        dao.insert(HighScoreEntity(mode = "endless", score = 500, maxChain = 3, characterId = "yuki", playedAt = 100))
        dao.insert(HighScoreEntity(mode = "scoreAttack", score = 9999, maxChain = 9, characterId = "rin", playedAt = 2000))
        val endlessTop = dao.top10("endless")
        assertEquals(3, endlessTop.size)
        assertEquals(500L, endlessTop[0].playedAt) // 同点で古い方が先
        assertEquals(1000L, endlessTop[1].playedAt)
        assertEquals(500L, endlessTop[2].score)
        val saTop = dao.top10("scoreAttack")
        assertEquals(1, saTop.size)
    }

    @Test
    fun storyProgressTable_upsertReplaces() = runTest {
        val dao = db.storyProgressDao()
        dao.upsert(StoryProgressEntity(id = "hina", clearedChapter = 1, updatedAt = 100))
        dao.upsert(StoryProgressEntity(id = "hina", clearedChapter = 2, updatedAt = 200))
        val row = dao.get("hina")
        assertNotNull(row)
        assertEquals(2, row!!.clearedChapter)
        assertEquals(200L, row.updatedAt)
    }

    @Test
    fun saveSlotTable_upsertAndDelete() = runTest {
        val dao = db.saveSlotDao()
        dao.upsert(SaveSlotEntity(slotIndex = 1, mode = "endless", serializedGameState = "{}", score = 100, savedAt = 1L))
        assertNotNull(dao.get(1))
        dao.deleteByIndex(1)
        assertNull(dao.get(1))
    }

    @Test
    fun autoSaveTable_singleRow() = runTest {
        val dao = db.autoSaveDao()
        assertNull(dao.get())
        dao.upsert(AutoSaveEntity(id = 0, mode = "endless", serializedGameState = "{}", savedAt = 999L))
        val row = dao.get()
        assertNotNull(row)
        assertEquals(0, row!!.id)
        assertEquals(999L, row.savedAt)
    }
}
