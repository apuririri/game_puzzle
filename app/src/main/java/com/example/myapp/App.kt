package com.example.myapp

import android.app.Application
import com.example.myapp.audio.AudioManager
import com.example.myapp.data.local.AppDatabase
import com.example.myapp.data.repository.CharacterRepository
import com.example.myapp.data.seed.AssetSeeder
import com.example.myapp.game.save.GameSnapshot
import com.example.myapp.game.save.SaveLoadManager
import com.example.myapp.recording.ChainClipRecorder
import com.example.myapp.settings.AppSettingsDataStore
import com.example.myapp.sharing.ScreenCapture
import com.example.myapp.util.AppLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * アプリケーションエントリポイント + シンプル DI。
 * 起動マーカー APP_STARTED は healthcheck / run.sh が起動確認に使う（削除禁止）。
 */
class App : Application() {

    lateinit var db: AppDatabase
        private set
    lateinit var settings: AppSettingsDataStore
        private set
    lateinit var characterRepo: CharacterRepository
        private set
    lateinit var audio: AudioManager
        private set
    lateinit var saveLoad: SaveLoadManager
        private set
    lateinit var screenCapture: ScreenCapture
        private set
    lateinit var clipRecorder: ChainClipRecorder
        private set
    lateinit var assetSeeder: AssetSeeder
        private set

    /**
     * 復帰用ゲーム状態。TitleScreen「つづきから」/ SaveSlotScreen「読み込み」で
     * autoSave / slot を読み込んで格納 → プレイ画面遷移後に EndlessScreen が
     * consumePendingResume() で取り出して VM.resumeFrom を呼ぶ。
     */
    private val _pendingResume = MutableStateFlow<GameSnapshot?>(null)
    val pendingResume: StateFlow<GameSnapshot?> = _pendingResume.asStateFlow()

    fun setPendingResume(snap: GameSnapshot?) { _pendingResume.value = snap }
    fun consumePendingResume(): GameSnapshot? {
        val v = _pendingResume.value
        _pendingResume.value = null
        return v
    }

    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        db = AppDatabase.getInstance(this)
        settings = AppSettingsDataStore(this)
        characterRepo = CharacterRepository(db.characterDao())
        audio = AudioManager(this, settings)
        saveLoad = SaveLoadManager(db.autoSaveDao(), db.saveSlotDao())
        screenCapture = ScreenCapture(this)
        clipRecorder = ChainClipRecorder(this, settings)
        assetSeeder = AssetSeeder(db.characterDao())

        appScope.launch {
            try { assetSeeder.seedIfEmpty() } catch (e: Exception) {
                AppLogger.dbError("AssetSeeder 失敗（起動継続）", e)
            }
        }

        AppLogger.app("APP_STARTED versionName=${BuildConfig.VERSION_NAME}")
    }
}
