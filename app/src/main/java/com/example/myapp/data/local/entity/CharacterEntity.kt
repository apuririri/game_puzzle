package com.example.myapp.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** キャラマスタ。設計書: docs/設計/features/共通基盤_AppDatabase.md / docs/設計/全体設計書.md §5.1 */
@Entity(tableName = "characters")
data class CharacterEntity(
    @PrimaryKey val id: String,
    val displayName: String,
    val voiceTone: String,
    val unlocked: Boolean = true,
)
