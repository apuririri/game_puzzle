package com.example.myapp.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.example.myapp.data.local.entity.SaveSlotEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface SaveSlotDao {
    @Query("SELECT * FROM save_slots ORDER BY slotIndex")
    fun observeAll(): Flow<List<SaveSlotEntity>>

    @Query("SELECT * FROM save_slots WHERE slotIndex = :index")
    suspend fun get(index: Int): SaveSlotEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(row: SaveSlotEntity)

    @Query("DELETE FROM save_slots WHERE slotIndex = :index")
    suspend fun deleteByIndex(index: Int)
}
