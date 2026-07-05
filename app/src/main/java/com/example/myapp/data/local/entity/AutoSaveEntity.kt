package com.example.myapp.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * オートセーブ単一行（id = 0 固定）。
 * 設計書: docs/設計/features/共通基盤_AppDatabase.md / 共通基盤_SaveLoadManager.md
 */
@Entity(tableName = "auto_save")
data class AutoSaveEntity(
    @PrimaryKey val id: Int = 0,
    val mode: String?,
    val serializedGameState: String?,
    val savedAt: Long?,
)
