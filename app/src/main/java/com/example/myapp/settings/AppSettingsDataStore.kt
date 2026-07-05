package com.example.myapp.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "app_settings")

/**
 * 美少女連鎖パズル 設定（DataStore）。
 * 設計書: docs/設計/features/共通基盤_SettingsRepository.md / docs/設計/全体設計書.md §6
 * 設定キーは必ずここに集約する（規約）。
 */
enum class Difficulty { Easy, Normal, Hard, Expert }

data class AppSettings(
    val difficulty: Difficulty = Difficulty.Normal,
    val bgmEnabled: Boolean = true,
    val bgmVolume: Float = 0.8f,
    val seEnabled: Boolean = true,
    val seVolume: Float = 1.0f,
    val voiceEnabled: Boolean = true,
    val voiceVolume: Float = 1.0f,
    val chainClipEnabled: Boolean = true,
    val selectedCharacterId: String = "hina",
    val tutorialLastViewedPage: Int = 0,
)

class AppSettingsDataStore(private val context: Context) {

    companion object {
        val KEY_DIFFICULTY = stringPreferencesKey("settings.difficulty")
        val KEY_BGM_ENABLED = booleanPreferencesKey("settings.bgm.enabled")
        val KEY_BGM_VOLUME = floatPreferencesKey("settings.bgm.volume")
        val KEY_SE_ENABLED = booleanPreferencesKey("settings.se.enabled")
        val KEY_SE_VOLUME = floatPreferencesKey("settings.se.volume")
        val KEY_VOICE_ENABLED = booleanPreferencesKey("settings.voice.enabled")
        val KEY_VOICE_VOLUME = floatPreferencesKey("settings.voice.volume")
        val KEY_CHAIN_CLIP_ENABLED = booleanPreferencesKey("settings.chainClip.enabled")
        val KEY_SELECTED_CHARACTER = stringPreferencesKey("selected.characterId")
        val KEY_TUTORIAL_LAST_PAGE = intPreferencesKey("tutorial.lastViewedPage")
    }

    val settings: Flow<AppSettings> = context.dataStore.data.map { p ->
        AppSettings(
            difficulty = runCatching { Difficulty.valueOf(p[KEY_DIFFICULTY] ?: "Normal") }
                .getOrDefault(Difficulty.Normal),
            bgmEnabled = p[KEY_BGM_ENABLED] ?: true,
            bgmVolume = p[KEY_BGM_VOLUME] ?: 0.8f,
            seEnabled = p[KEY_SE_ENABLED] ?: true,
            seVolume = p[KEY_SE_VOLUME] ?: 1.0f,
            voiceEnabled = p[KEY_VOICE_ENABLED] ?: true,
            voiceVolume = p[KEY_VOICE_VOLUME] ?: 1.0f,
            chainClipEnabled = p[KEY_CHAIN_CLIP_ENABLED] ?: true,
            selectedCharacterId = p[KEY_SELECTED_CHARACTER] ?: "hina",
            tutorialLastViewedPage = p[KEY_TUTORIAL_LAST_PAGE] ?: 0,
        )
    }

    suspend fun setDifficulty(value: Difficulty) {
        context.dataStore.edit { it[KEY_DIFFICULTY] = value.name }
    }
    suspend fun setBgmEnabled(value: Boolean) {
        context.dataStore.edit { it[KEY_BGM_ENABLED] = value }
    }
    suspend fun setBgmVolume(value: Float) {
        context.dataStore.edit { it[KEY_BGM_VOLUME] = value.coerceIn(0f, 1f) }
    }
    suspend fun setSeEnabled(value: Boolean) {
        context.dataStore.edit { it[KEY_SE_ENABLED] = value }
    }
    suspend fun setSeVolume(value: Float) {
        context.dataStore.edit { it[KEY_SE_VOLUME] = value.coerceIn(0f, 1f) }
    }
    suspend fun setVoiceEnabled(value: Boolean) {
        context.dataStore.edit { it[KEY_VOICE_ENABLED] = value }
    }
    suspend fun setVoiceVolume(value: Float) {
        context.dataStore.edit { it[KEY_VOICE_VOLUME] = value.coerceIn(0f, 1f) }
    }
    suspend fun setChainClipEnabled(value: Boolean) {
        context.dataStore.edit { it[KEY_CHAIN_CLIP_ENABLED] = value }
    }
    suspend fun setSelectedCharacterId(value: String) {
        context.dataStore.edit { it[KEY_SELECTED_CHARACTER] = value }
    }
    suspend fun setTutorialLastViewedPage(value: Int) {
        context.dataStore.edit { it[KEY_TUTORIAL_LAST_PAGE] = value }
    }
}
