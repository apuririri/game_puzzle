package com.example.myapp.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * キャラ別立ち絵バリエーション。variant は normal/joy/anger/sad/chain/bigChain/lose。
 * 設計書: docs/設計/features/共通基盤_AppDatabase.md
 */
@Entity(
    tableName = "character_images",
    foreignKeys = [
        ForeignKey(
            entity = CharacterEntity::class,
            parentColumns = ["id"],
            childColumns = ["characterId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
    indices = [Index("characterId")],
)
data class CharacterImageEntity(
    @PrimaryKey val id: String,
    val characterId: String,
    val variant: String,
    val assetPath: String,
)
