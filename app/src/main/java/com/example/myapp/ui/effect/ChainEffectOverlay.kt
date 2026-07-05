package com.example.myapp.ui.effect

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapp.domain.game.CellColor
import com.example.myapp.domain.game.ChainEvent
import com.example.myapp.domain.model.CharacterVariant
import com.example.myapp.ui.component.CharacterImage
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow

/**
 * 連鎖演出オーバーレイ。設計書: docs/設計/features/共通基盤_ChainEffectRenderer.md
 * 連鎖レベルに応じた4 段階の演出を組み合わせ、爽快感とインパクトを最大化する。
 *
 *   MILD  (1連鎖): 控えめな背景フラッシュ + 軽いパーティクル + 立ち絵右下小さめ + テキスト軽くポップ
 *   MEDIUM(2連鎖): カラーグラデ背景 + 立ち絵中央寄せスケール + テキスト回転 + 軽いシェイク
 *   BIG   (3-4連鎖): 放射状リング波紋 + パーティクル増 + シェイク中 + 立ち絵 CHAIN variant 大表示
 *   ULTRA (5+連鎖): 虹色グラデ + 立ち絵 BIG_CHAIN variant パルス + 大文字回転テキスト +
 *                  画面シェイク強 + 多重リング波紋 + 大量パーティクル + BGM intensify マーカー
 */
enum class EffectTier {
    MILD,    // 1
    MEDIUM,  // 2
    BIG,     // 3,4
    ULTRA;   // 5+

    companion object {
        fun of(level: Int): EffectTier = when {
            level >= 5 -> ULTRA
            level >= 3 -> BIG
            level >= 2 -> MEDIUM
            else -> MILD
        }
    }
}

private fun durationFor(level: Int): Long = when {
    level >= 5 -> 1300L
    level >= 3 -> 1000L
    level >= 2 -> 800L
    else -> 600L
}

private fun shakeStrengthDp(tier: EffectTier): Float = when (tier) {
    EffectTier.MILD -> 0f
    EffectTier.MEDIUM -> 2f
    EffectTier.BIG -> 6f
    EffectTier.ULTRA -> 14f
}

@Composable
fun ChainEffectOverlay(
    events: Flow<ChainEvent>,
    modifier: Modifier = Modifier,
    characterId: String? = null,
) {
    var current by remember { mutableStateOf<ChainEvent?>(null) }

    LaunchedEffect(events) {
        events.collect { event ->
            current = event
            delay(durationFor(event.level))
            current = null
        }
    }

    val tier = current?.let { EffectTier.of(it.level) } ?: EffectTier.MILD
    val active = current != null

    // 画面シェイク（sin/cos 揺らぎ）
    val infinite = rememberInfiniteTransition(label = "shake-clock")
    val shakeClock by infinite.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(80, easing = LinearEasing), repeatMode = RepeatMode.Restart),
        label = "shake-clock",
    )
    val shakeStr = shakeStrengthDp(tier)
    val shakeX = if (active && shakeStr > 0) (sin(shakeClock * Math.PI.toFloat() * 12) * shakeStr).dp else 0.dp
    val shakeY = if (active && shakeStr > 0) (cos(shakeClock * Math.PI.toFloat() * 11) * shakeStr).dp else 0.dp

    Box(modifier = modifier.fillMaxSize()) {
        Box(
            modifier = Modifier.fillMaxSize()
                .offset(x = shakeX, y = shakeY)
                .testTag("chain_screen_shake"),
        ) {
            BackgroundFlash(active, tier, current)
            RingWaves(active, tier, current)
            ParticleField(active, tier, current)
            CharacterStandee(active, tier, characterId, current)
            ChainCountText(active, tier, current)
        }
        if (tier == EffectTier.ULTRA && active) {
            Box(modifier = Modifier.testTag("chain_bgm_intensify"))
        }
    }
}

/** 背景フラッシュ（tier 別の色と alpha）。 */
@Composable
private fun BackgroundFlash(active: Boolean, tier: EffectTier, event: ChainEvent?) {
    val target = if (active) when (tier) {
        EffectTier.MILD -> 0.10f
        EffectTier.MEDIUM -> 0.22f
        EffectTier.BIG -> 0.35f
        EffectTier.ULTRA -> 0.50f
    } else 0f
    val a by animateFloatAsState(target, tween(if (active) 120 else 350), label = "flash")
    val brush = when (tier) {
        EffectTier.MILD -> Brush.verticalGradient(listOf(Color.White.copy(alpha = a), Color.Transparent))
        EffectTier.MEDIUM -> Brush.linearGradient(
            listOf(Color(0xFFFFD0E0).copy(alpha = a), Color(0xFFD0E5FF).copy(alpha = a)),
        )
        EffectTier.BIG -> Brush.radialGradient(
            listOf(Color(0xFFFFE680).copy(alpha = a * 1.2f), Color(0xFFFF6FA8).copy(alpha = a * 0.6f), Color.Transparent),
        )
        EffectTier.ULTRA -> Brush.sweepGradient(
            listOf(
                Color(0xFFFF3366), Color(0xFFFF9933), Color(0xFFFFEE00),
                Color(0xFF33FF66), Color(0xFF33CCFF), Color(0xFF9933FF),
                Color(0xFFFF3366),
            ).map { it.copy(alpha = a) },
        )
    }
    Box(modifier = Modifier.fillMaxSize().background(brush).testTag("chain_background_flash"))
}

/** 同心円波紋。BIG 以上で 1 本、ULTRA で 3 本を時間差発火。 */
@Composable
private fun RingWaves(active: Boolean, tier: EffectTier, event: ChainEvent?) {
    if (!active || tier == EffectTier.MILD || tier == EffectTier.MEDIUM) return
    val rings = if (tier == EffectTier.ULTRA) 3 else 1
    val color = when (tier) {
        EffectTier.ULTRA -> Color(0xFFFFD700)
        else -> Color(0xFF00E5FF)
    }
    val transition = rememberInfiniteTransition(label = "ring-clock")
    val t by transition.animateFloat(
        0f, 1f,
        infiniteRepeatable(tween(700, easing = LinearEasing), repeatMode = RepeatMode.Restart),
        label = "ring-clock",
    )
    Canvas(modifier = Modifier.fillMaxSize().testTag("chain_ring_waves")) {
        val cx = size.width / 2f
        val cy = size.height / 2f
        val maxR = minOf(size.width, size.height) * 0.7f
        for (i in 0 until rings) {
            val phase = ((t + i * 0.33f) % 1f)
            val r = phase * maxR
            val alpha = (1f - phase).coerceIn(0f, 1f) * 0.85f
            drawCircle(
                color = color.copy(alpha = alpha),
                radius = r,
                center = Offset(cx, cy),
                style = Stroke(width = (4f + i * 2f).coerceAtMost(10f)),
            )
        }
    }
}

/** パーティクル（tier 別個数、消去色に応じた配色）。 */
@Composable
private fun ParticleField(active: Boolean, tier: EffectTier, event: ChainEvent?) {
    if (!active) return
    val particleCount = when (tier) {
        EffectTier.MILD -> 12
        EffectTier.MEDIUM -> 24
        EffectTier.BIG -> 48
        EffectTier.ULTRA -> 96
    }
    val seed = event?.level ?: 1
    val colors = (event?.colors?.map { cellToColor(it) }?.takeIf { it.isNotEmpty() })
        ?: listOf(Color(0xFFFF6FA8), Color(0xFFFFE680))
    // 0 → 1 の進捗をアニメ
    val progress by animateFloatAsState(if (active) 1f else 0f, tween(durationFor(event?.level ?: 1).toInt()), label = "particles")
    Canvas(modifier = Modifier.fillMaxSize().testTag("chain_particle_layer")) {
        val cx = size.width / 2f
        val cy = size.height / 2f
        val rand = Random(seed * 7919)
        repeat(particleCount) { i ->
            val angle = rand.nextFloat() * Math.PI.toFloat() * 2f
            val radiusMax = minOf(size.width, size.height) * (0.25f + rand.nextFloat() * 0.55f)
            val r = radiusMax * progress
            val x = cx + cos(angle) * r
            val y = cy + sin(angle) * r
            val sz = (6f + rand.nextFloat() * 10f) * (1.2f - progress * 0.6f)
            val c = colors[i % colors.size].copy(alpha = (1f - progress).coerceIn(0f, 0.9f))
            drawCircle(color = c, radius = sz, center = Offset(x, y))
        }
    }
}

/** キャラ立ち絵差し替え。tier 別 variant / 位置 / scale。ULTRA はパルスアニメ付き。 */
@Composable
private fun CharacterStandee(active: Boolean, tier: EffectTier, characterId: String?, event: ChainEvent?) {
    if (!active || characterId == null) return
    val variant = when (tier) {
        EffectTier.MILD -> CharacterVariant.NORMAL
        EffectTier.MEDIUM -> CharacterVariant.JOY
        EffectTier.BIG -> CharacterVariant.CHAIN
        EffectTier.ULTRA -> CharacterVariant.BIG_CHAIN
    }
    val alignment = when (tier) {
        EffectTier.MILD -> Alignment.BottomEnd
        EffectTier.MEDIUM -> Alignment.BottomCenter
        EffectTier.BIG -> Alignment.Center
        EffectTier.ULTRA -> Alignment.Center
    }
    val heightDp = when (tier) {
        EffectTier.MILD -> 140.dp
        EffectTier.MEDIUM -> 200.dp
        EffectTier.BIG -> 280.dp
        EffectTier.ULTRA -> 380.dp
    }
    // ULTRA はパルス（1.0 ↔ 1.12）、BIG は控えめパルス、それ以下は固定
    val transition = rememberInfiniteTransition(label = "char-pulse")
    val pulse by transition.animateFloat(
        1f, if (tier == EffectTier.ULTRA) 1.12f else if (tier == EffectTier.BIG) 1.05f else 1f,
        infiniteRepeatable(tween(360, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "char-pulse",
    )
    val popIn by animateFloatAsState(if (active) 1f else 0.3f, tween(220), label = "char-popin")
    Box(
        modifier = Modifier.fillMaxSize().padding(16.dp).testTag("chain_character_overlay"),
        contentAlignment = alignment,
    ) {
        CharacterImage(
            characterId = characterId,
            variant = variant,
            modifier = Modifier
                .height(heightDp)
                .scale(popIn * pulse)
                .alpha(0.92f),
        )
    }
}

/** 連鎖数テキスト（tier 別フォントサイズ・色・回転）。ULTRA は虹色グラデ + 回転 + ズーム。 */
@Composable
private fun ChainCountText(active: Boolean, tier: EffectTier, event: ChainEvent?) {
    if (!active) return
    val level = event?.level ?: 1
    val (text, fontSize, color, rotation) = when (tier) {
        EffectTier.MILD -> Quad("いっき！", 44.sp, Color(0xFFFF6FA8), 0f)
        EffectTier.MEDIUM -> Quad("にれんさ！", 64.sp, Color(0xFF7C4DFF), -8f)
        EffectTier.BIG -> Quad("$level 連鎖!!", 88.sp, Color(0xFFFFD700), -12f)
        EffectTier.ULTRA -> Quad("だい・れん・さーー！！", 108.sp, Color(0xFFFFFFFF), -18f)
    }
    val zoom by animateFloatAsState(if (active) 1f else 0.4f, tween(180), label = "text-zoom")
    Box(
        modifier = Modifier.fillMaxSize().testTag("chain_count_overlay"),
        contentAlignment = Alignment.Center,
    ) {
        if (tier == EffectTier.ULTRA) {
            // 多重描画で派手化（影 + 本体）
            Text(
                text = text, fontSize = fontSize, fontWeight = FontWeight.Black,
                color = Color(0xFFFF3366),
                modifier = Modifier.scale(zoom * 1.04f).rotate(rotation).alpha(0.85f).offset(x = 3.dp, y = 3.dp),
            )
        }
        Text(
            text = text,
            fontSize = fontSize,
            fontWeight = FontWeight.Black,
            color = color,
            modifier = Modifier.scale(zoom).rotate(rotation),
        )
    }
}

private data class Quad(val text: String, val fontSize: androidx.compose.ui.unit.TextUnit, val color: Color, val rotation: Float)

private fun cellToColor(c: CellColor): Color = when (c) {
    CellColor.RED -> Color(0xFFE53935)
    CellColor.GREEN -> Color(0xFF43A047)
    CellColor.BLUE -> Color(0xFF1E88E5)
    CellColor.YELLOW -> Color(0xFFFDD835)
    CellColor.PURPLE -> Color(0xFF8E24AA)
    CellColor.OJAMA -> Color(0xFF888888)
}
