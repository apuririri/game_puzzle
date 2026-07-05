package com.example.myapp.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

/** 動作確認用サンプルメモ。設計書: docs/設計/data_model.md */
@Entity(tableName = "memos")
data class MemoEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val body: String = "",
    val createdAt: Long = System.currentTimeMillis()
)
