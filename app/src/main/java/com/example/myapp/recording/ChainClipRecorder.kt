package com.example.myapp.recording

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import com.example.myapp.domain.game.ChainEvent
import com.example.myapp.settings.AppSettingsDataStore
import kotlinx.coroutines.flow.first
import java.io.OutputStream

/**
 * 5+連鎖検知時に演出区間を端末ギャラリーへ保存する。
 * 設計書: docs/設計/features/共通基盤_ChainClipRecorder.md / 大連鎖クリップ自動保存.md
 *
 * 本実装は API スケルトン: MediaCodec/MediaMuxer の実エンコードは Compose View の
 * Surface 取り扱いと密結合のため、シェアシート用 PNG スナップショット保存 + ファイル名
 * `美少女連鎖パズル_<ts>.mp4` のプレースホルダー出力で初期出荷する（後続 fix-loop で
 * mp4 エンコードを差し替える）。
 *
 * MediaStore 経由（API 29+ scoped storage）で保存し、戻り値の Uri を呼び出し側に渡す。
 */
class ChainClipRecorder(
    private val context: Context,
    private val settings: AppSettingsDataStore,
) {
    /** 5 連鎖以上のとき MediaStore に動画ファイル枠を作成し、暫定データを書き込む。実装初期段階。 */
    suspend fun captureIfBigChain(event: ChainEvent, snapshotBytes: ByteArray?): Uri? {
        if (event.level < 5) return null
        val s = settings.settings.first()
        if (!s.chainClipEnabled) return null

        val ts = System.currentTimeMillis()
        val fileName = "美少女連鎖パズル_$ts.mp4"
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/BishojoChainPuzzle")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
            }
            val resolver = context.contentResolver
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
            val uri = resolver.insert(collection, values) ?: return null
            resolver.openOutputStream(uri)?.use { os: OutputStream ->
                snapshotBytes?.let { os.write(it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Video.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }
            Log.i("ClipLog", "保存: $fileName (uri=$uri, level=${event.level})")
            uri
        } catch (e: Exception) {
            Log.w("ClipLog", "クリップ保存失敗（スキップ）: ${e.message}")
            null
        }
    }
}
