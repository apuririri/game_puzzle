package com.example.myapp.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * ストーリーモード進行（characterId 毎の最終クリア章）。
 * 設計書: docs/設計/features/共通基盤_AppDatabase.md / ストーリーモード.md
 */
@Entity(tableName = "story_progress")
data class StoryProgressEntity(
    @PrimaryKey val id: String, // = characterId
    val clearedChapter: Int = 0,
    val updatedAt: Long,
)
