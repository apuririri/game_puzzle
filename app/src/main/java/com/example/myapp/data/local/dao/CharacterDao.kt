package com.example.myapp.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.example.myapp.data.local.entity.CharacterEntity
import com.example.myapp.data.local.entity.CharacterImageEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface CharacterDao {
    @Query("SELECT * FROM characters ORDER BY id")
    fun observeAll(): Flow<List<CharacterEntity>>

    @Query("SELECT * FROM characters WHERE id = :id")
    suspend fun get(id: String): CharacterEntity?

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAll(rows: List<CharacterEntity>): List<Long>

    @Query("SELECT * FROM character_images WHERE characterId = :characterId")
    suspend fun imagesOf(characterId: String): List<CharacterImageEntity>

    @Query("SELECT * FROM character_images")
    fun observeAllImages(): Flow<List<CharacterImageEntity>>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAllImages(rows: List<CharacterImageEntity>): List<Long>

    @Query("SELECT COUNT(*) FROM characters")
    suspend fun count(): Int
}
