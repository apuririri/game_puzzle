package com.example.myapp.data.local.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * ランキング TOP10。mode = endless / scoreAttack / cpuBattle。
 * 設計書: docs/設計/features/共通基盤_AppDatabase.md / ローカルランキング.md
 */
@Entity(
    tableName = "high_scores",
    indices = [Index("mode"), Index(value = ["mode", "score"])],
)
data class HighScoreEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val mode: String,
    val score: Long,
    val maxChain: Int,
    val characterId: String,
    val playedAt: Long,
)
