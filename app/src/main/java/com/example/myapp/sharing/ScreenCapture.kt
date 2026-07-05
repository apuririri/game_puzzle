package com.example.myapp.sharing

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.view.View
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream

/**
 * 画面キャプチャ → FileProvider → ACTION_SEND。
 * 設計書: docs/設計/features/共通基盤_ScreenCapture.md / スクリーンショット共有.md
 */
class ScreenCapture(private val context: Context) {

    /**
     * 戻り値: 起動可能な Intent。呼び出し側が startActivity(Intent.createChooser(intent, title))。
     * 例外時は IOException を流す（呼び出し側で再試行案内 Toast を出す）。
     */
    fun captureAndCreateShareIntent(view: View, title: String): Intent {
        val bitmap = Bitmap.createBitmap(view.width.coerceAtLeast(1), view.height.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        val dir = File(context.cacheDir, "shared_screenshots").apply { mkdirs() }
        val file = File(dir, "shot_${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { os ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, os)
        }
        val uri: Uri = FileProvider.getUriForFile(
            context, "${context.packageName}.fileprovider", file
        )
        return Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TITLE, title)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }
}
