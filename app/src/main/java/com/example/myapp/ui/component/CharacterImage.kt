package com.example.myapp.ui.component

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import com.example.myapp.domain.model.CharacterVariant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException

/**
 * assets/image/character/<id>/<variant>.webp を非同期にロードして描画する。
 * 画像が存在しない or 読込失敗時はキャラ ID テキストをプレースホルダー表示（要件のとおり）。
 *
 * variant 切替時の描画ちらつき防止:
 *  - remember の key に (characterId, variant) を渡さない → 前回 bitmap を保持
 *  - LaunchedEffect の key に (characterId, variant) を渡し新しい bitmap を非同期ロード
 *  - ロード成功時に一気に差替（旧 bitmap は残ったままなので白フラッシュしない）
 *
 * 設計書: docs/設計/features/共通基盤_CharacterRepository.md / キャラクター選択.md
 */
@Composable
fun CharacterImage(
    characterId: String,
    variant: CharacterVariant = CharacterVariant.NORMAL,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Fit,
    fallbackLabel: String? = null,
) {
    val ctx = LocalContext.current
    var bitmap by remember { mutableStateOf<ImageBitmap?>(null) }
    var failed by remember { mutableStateOf(false) }

    LaunchedEffect(characterId, variant) {
        failed = false  // 旧 bitmap は保持したまま新しい画像をロード（フラッシュ防止）
        val path = "image/character/$characterId/${variant.asAssetSuffix()}.webp"
        val loaded = withContext(Dispatchers.IO) {
            try {
                ctx.assets.open(path).use { input ->
                    BitmapFactory.decodeStream(input)
                }
            } catch (e: IOException) {
                null
            }
        }
        if (loaded != null) bitmap = loaded.asImageBitmap() else if (bitmap == null) failed = true
    }

    val img = bitmap
    if (img != null) {
        Image(
            bitmap = img,
            contentDescription = "$characterId (${variant.asAssetSuffix()})",
            modifier = modifier,
            contentScale = contentScale,
        )
    } else {
        Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                text = fallbackLabel ?: characterId,
                color = MaterialTheme.colorScheme.tertiary,
            )
        }
    }
}
