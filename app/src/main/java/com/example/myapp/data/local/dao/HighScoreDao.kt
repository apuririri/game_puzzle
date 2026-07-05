package com.example.myapp.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.example.myapp.data.local.entity.HighScoreEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface HighScoreDao {
    @Query("SELECT * FROM high_scores WHERE mode = :mode ORDER BY score DESC, playedAt ASC LIMIT 10")
    fun observeTop10(mode: String): Flow<List<HighScoreEntity>>

    @Query("SELECT * FROM high_scores WHERE mode = :mode ORDER BY score DESC, playedAt ASC LIMIT 10")
    suspend fun top10(mode: String): List<HighScoreEntity>

    @Insert
    suspend fun insert(row: HighScoreEntity): Long

    @Query("DELETE FROM high_scores")
    suspend fun deleteAll()
}
