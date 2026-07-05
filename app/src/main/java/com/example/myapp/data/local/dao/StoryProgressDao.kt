package com.example.myapp.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.example.myapp.data.local.entity.StoryProgressEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface StoryProgressDao {
    @Query("SELECT * FROM story_progress")
    fun observeAll(): Flow<List<StoryProgressEntity>>

    @Query("SELECT * FROM story_progress WHERE id = :characterId")
    suspend fun get(characterId: String): StoryProgressEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(row: StoryProgressEntity)
}
