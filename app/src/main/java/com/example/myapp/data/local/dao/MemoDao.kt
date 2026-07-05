package com.example.myapp.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.example.myapp.data.local.entity.MemoEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface MemoDao {
    @Query("SELECT * FROM memos ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<MemoEntity>>

    @Insert
    suspend fun insert(memo: MemoEntity): Long

    @Query("DELETE FROM memos WHERE id = :id")
    suspend fun deleteById(id: Long)
}
