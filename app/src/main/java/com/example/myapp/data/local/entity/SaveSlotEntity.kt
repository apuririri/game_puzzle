package com.example.myapp.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * 手動セーブスロット。1..10。
 * 設計書: docs/設計/features/共通基盤_AppDatabase.md / セーブ_ロード.md
 */
@Entity(tableName = "save_slots")
data class SaveSlotEntity(
    @PrimaryKey val slotIndex: Int,
    val mode: String,
    val serializedGameState: String,
    val score: Long,
    val savedAt: Long,
)
