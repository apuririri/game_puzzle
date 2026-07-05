package com.example.myapp.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.example.myapp.data.local.dao.AutoSaveDao
import com.example.myapp.data.local.dao.CharacterDao
import com.example.myapp.data.local.dao.HighScoreDao
import com.example.myapp.data.local.dao.MemoDao
import com.example.myapp.data.local.dao.SaveSlotDao
import com.example.myapp.data.local.dao.StoryProgressDao
import com.example.myapp.data.local.entity.AutoSaveEntity
import com.example.myapp.data.local.entity.CharacterEntity
import com.example.myapp.data.local.entity.CharacterImageEntity
import com.example.myapp.data.local.entity.HighScoreEntity
import com.example.myapp.data.local.entity.MemoEntity
import com.example.myapp.data.local.entity.SaveSlotEntity
import com.example.myapp.data.local.entity.StoryProgressEntity

/**
 * Room データベース。設計書: docs/設計/全体設計書.md §5.
 * - exportSchema = true（schema JSON は app/schemas/ に git tracked）
 * - version を上げたら Migration + MigrationTest 必須（check_room_schema.sh がゲート）
 */
@Database(
    entities = [
        MemoEntity::class,
        CharacterEntity::class,
        CharacterImageEntity::class,
        HighScoreEntity::class,
        StoryProgressEntity::class,
        SaveSlotEntity::class,
        AutoSaveEntity::class,
    ],
    version = 1,
    exportSchema = true
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun memoDao(): MemoDao
    abstract fun characterDao(): CharacterDao
    abstract fun highScoreDao(): HighScoreDao
    abstract fun storyProgressDao(): StoryProgressDao
    abstract fun saveSlotDao(): SaveSlotDao
    abstract fun autoSaveDao(): AutoSaveDao

    companion object {
        @Volatile
        private var instance: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "app.db"
                ).build().also { instance = it }
            }
    }
}
