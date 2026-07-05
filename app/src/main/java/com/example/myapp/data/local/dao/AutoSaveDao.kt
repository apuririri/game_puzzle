package com.example.myapp.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.example.myapp.data.local.entity.AutoSaveEntity

@Dao
interface AutoSaveDao {
    @Query("SELECT * FROM auto_save WHERE id = 0")
    suspend fun get(): AutoSaveEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(row: AutoSaveEntity)

    @Query("DELETE FROM auto_save")
    suspend fun clear()
}
