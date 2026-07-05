package com.example.myapp.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager as AndroidAudioManager
import android.media.MediaPlayer
import android.media.SoundPool
import android.os.Build
import com.example.myapp.settings.AppSettings
import com.example.myapp.settings.AppSettingsDataStore
import android.util.Log
import com.example.myapp.util.AppLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.IOException

/**
 * BGM / SE / Voice 統合再生。設計書: docs/設計/features/共通基盤_AudioManager.md
 *
 * BGM: MediaPlayer（同時 1 つ。シーン切替で stop→start）
 * SE:  SoundPool（同時最大 6）
 * Voice: MediaPlayer（前ボイス停止→新規）
 *
 * 設定 ON/OFF と音量は SettingsRepository から購読し即時反映。
 */
sealed class AudioCue {
    data class Bgm(val sceneId: String) : AudioCue()
    data class Se(val eventId: String) : AudioCue()
    data class Voice(val characterId: String, val eventId: String) : AudioCue()
}

class AudioManager(
    private val context: Context,
    private val settings: AppSettingsDataStore,
) {
    private val androidAudio = context.getSystemService(Context.AUDIO_SERVICE) as AndroidAudioManager
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var bgmPlayer: MediaPlayer? = null
    private var voicePlayer: MediaPlayer? = null
    private var currentBgmScene: String? = null

    private val soundPool: SoundPool = SoundPool.Builder()
        .setMaxStreams(6)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()
    private val seCache = mutableMapOf<String, Int>()

    private val _currentSettings = MutableStateFlow(AppSettings())
    val currentSettings: StateFlow<AppSettings> = _currentSettings

    private val focusListener = AndroidAudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AndroidAudioManager.AUDIOFOCUS_LOSS,
            AndroidAudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                bgmPlayer?.pause()
                voicePlayer?.pause()
            }
            AndroidAudioManager.AUDIOFOCUS_GAIN -> {
                // BGM のみ復帰、Voice/SE はそのまま停止維持（設計通り）
                bgmPlayer?.start()
            }
        }
    }
    private var audioFocusRequest: AudioFocusRequest? = null

    init {
        scope.launch {
            settings.settings.collect { current ->
                val prev = _currentSettings.value
                _currentSettings.value = current
                // BGM 音量は再生中の MediaPlayer に即時反映
                bgmPlayer?.setVolume(current.bgmVolume, current.bgmVolume)
                voicePlayer?.setVolume(current.voiceVolume, current.voiceVolume)
                // BGM トグル変化に応じて pause / resume
                if (prev.bgmEnabled && !current.bgmEnabled) bgmPlayer?.pause()
                if (!prev.bgmEnabled && current.bgmEnabled) bgmPlayer?.start()
            }
        }
    }

    fun play(cue: AudioCue) {
        when (cue) {
            is AudioCue.Bgm -> playBgm(cue.sceneId)
            is AudioCue.Se -> playSe(cue.eventId)
            is AudioCue.Voice -> playVoice(cue.characterId, cue.eventId)
        }
    }

    fun playBgm(sceneId: String) {
        val s = _currentSettings.value
        if (!s.bgmEnabled) return
        if (currentBgmScene == sceneId && bgmPlayer?.isPlaying == true) return
        bgmPlayer?.release()
        currentBgmScene = sceneId
        bgmPlayer = openAsset("bgm/$sceneId.ogg")?.apply {
            isLooping = true
            setVolume(s.bgmVolume, s.bgmVolume)
            requestFocus()
            start()
        }
    }

    fun stopBgm() {
        bgmPlayer?.release()
        bgmPlayer = null
        currentBgmScene = null
        abandonFocus()
    }

    fun playSe(eventId: String) {
        val s = _currentSettings.value
        if (!s.seEnabled) return
        val key = "se/$eventId.ogg"
        val sid = seCache[key] ?: try {
            val afd = context.assets.openFd(key)
            val id = soundPool.load(afd, 1)
            seCache[key] = id
            id
        } catch (e: IOException) {
            Log.w("AudioLog", "SE 未存在をスキップ: $key")
            return
        }
        soundPool.play(sid, s.seVolume, s.seVolume, 1, 0, 1.0f)
    }

    private val voiceCandidateCache = mutableMapOf<Pair<String, String>, List<String>>()

    fun playVoice(characterId: String, eventId: String) {
        val s = _currentSettings.value
        if (!s.voiceEnabled) return
        // 存在チェック結果をキャッシュ（起動中に一度きり I/O）
        val candidates = voiceCandidateCache.getOrPut(characterId to eventId) {
            listOf(eventId, "${eventId}_alt1", "${eventId}_alt2")
                .filter { context.assets.exists("voice/$characterId/$it.ogg") }
        }
        val chosen = if (candidates.isEmpty()) eventId else candidates.random()
        voicePlayer?.release()
        voicePlayer = openAsset("voice/$characterId/$chosen.ogg")?.apply {
            setVolume(s.voiceVolume, s.voiceVolume)
            start()
        }
    }

    private fun android.content.res.AssetManager.exists(path: String): Boolean {
        return try { open(path).use { true } } catch (_: IOException) { false }
    }

    private fun openAsset(path: String): MediaPlayer? {
        return try {
            val afd = context.assets.openFd(path)
            MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                prepare()
            }
        } catch (e: IOException) {
            Log.w("AudioLog", "音声ファイル未存在をスキップ: $path")
            null
        }
    }

    private fun requestFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AndroidAudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            audioFocusRequest = req
            androidAudio.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            androidAudio.requestAudioFocus(focusListener, AndroidAudioManager.STREAM_MUSIC, AndroidAudioManager.AUDIOFOCUS_GAIN)
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { androidAudio.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            androidAudio.abandonAudioFocus(focusListener)
        }
    }

    fun release() {
        bgmPlayer?.release()
        voicePlayer?.release()
        soundPool.release()
        abandonFocus()
    }

}
