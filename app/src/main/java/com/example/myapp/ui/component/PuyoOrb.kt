package com.example.myapp.ui.component

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import com.example.myapp.domain.game.CellColor
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * 落ちゲー用の 6 種宝石オーブを Compose Canvas で描画する。
 *
 * 各色は「(1) 色別の宝石形状（heart / clover / drop / star / crescent / bomb） +
 * (2) radial gradient で 3D 感 + (3) 白い光沢 highlight + (4) 淡い外側 glow」の
 * 4 レイヤー構成。市販の落ちゲー（ぷよぷよ / パズドラ / ツムツム）が採用している
 * 「シルエットで色が識別でき、光沢で立体感を出す」設計を踏襲。
 *
 * 設計書: docs/設計/features/共通基盤_ChainEngine.md / エンドレスモード.md
 */
@Composable
fun PuyoOrb(color: CellColor, modifier: Modifier = Modifier) {
    val palette = paletteFor(color)
    Canvas(modifier = modifier) {
        val d = min(size.width, size.height)
        val cx = size.width / 2f
        val cy = size.height / 2f

        // (1) 外側 glow（ふわっとしたハロ効果）
        val glow = Brush.radialGradient(
            colors = listOf(palette.mid.copy(alpha = 0.55f), palette.mid.copy(alpha = 0f)),
            center = Offset(cx, cy),
            radius = d * 0.62f,
        )
        drawCircle(brush = glow, radius = d * 0.55f, center = Offset(cx, cy))

        // (2) メインシェイプ（色別）+ radial gradient
        val shapeSize = d * 0.88f
        val shapePath = shapePathFor(color, cx, cy, shapeSize)
        val bodyGrad = Brush.radialGradient(
            colors = listOf(palette.light, palette.mid, palette.dark),
            center = Offset(cx - shapeSize * 0.15f, cy - shapeSize * 0.20f),
            radius = shapeSize * 0.75f,
        )
        drawPath(shapePath, brush = bodyGrad)

        // (3) 縁取り（暗色で締める）
        drawPath(
            shapePath,
            color = palette.dark.copy(alpha = 0.85f),
            style = Stroke(width = d * 0.045f),
        )

        // (4) 白の光沢 highlight（上部左）
        val hlSize = shapeSize * 0.35f
        val hlCx = cx - shapeSize * 0.22f
        val hlCy = cy - shapeSize * 0.24f
        val hlGrad = Brush.radialGradient(
            colors = listOf(Color.White.copy(alpha = 0.85f), Color.White.copy(alpha = 0f)),
            center = Offset(hlCx, hlCy),
            radius = hlSize * 0.9f,
        )
        drawCircle(brush = hlGrad, radius = hlSize, center = Offset(hlCx, hlCy))

        // (5) 中央アイコン（色別の小さなシンボル）— 白で微かに
        drawIconOverlay(color, cx, cy, d)
    }
}

private data class OrbPalette(val light: Color, val mid: Color, val dark: Color)

private fun paletteFor(c: CellColor): OrbPalette = when (c) {
    CellColor.RED -> OrbPalette(Color(0xFFFFB3B3), Color(0xFFF03A47), Color(0xFF9E1C2A))
    CellColor.GREEN -> OrbPalette(Color(0xFFB3F0A6), Color(0xFF3AB745), Color(0xFF1E6A24))
    CellColor.BLUE -> OrbPalette(Color(0xFFA6D8FF), Color(0xFF2F8FDD), Color(0xFF124A85))
    CellColor.YELLOW -> OrbPalette(Color(0xFFFFF3A6), Color(0xFFFFC22E), Color(0xFFB77800))
    CellColor.PURPLE -> OrbPalette(Color(0xFFE3B8FF), Color(0xFF9B47DB), Color(0xFF561B85))
    CellColor.OJAMA -> OrbPalette(Color(0xFFAAAAAA), Color(0xFF666666), Color(0xFF222222))
}

/**
 * 色別のメインシェイプ。R=ハート / G=クローバー / B=雫 / Y=星 / P=三日月 / O=角丸四角+X。
 */
private fun shapePathFor(color: CellColor, cx: Float, cy: Float, size: Float): Path = Path().apply {
    val r = size / 2f
    when (color) {
        CellColor.RED -> {
            // ハート形
            moveTo(cx, cy + r * 0.85f)
            cubicTo(
                cx - r * 1.15f, cy + r * 0.10f,
                cx - r * 0.90f, cy - r * 0.85f,
                cx, cy - r * 0.35f,
            )
            cubicTo(
                cx + r * 0.90f, cy - r * 0.85f,
                cx + r * 1.15f, cy + r * 0.10f,
                cx, cy + r * 0.85f,
            )
            close()
        }
        CellColor.GREEN -> {
            // クローバー: 4 円の重ね合わせで葉っぱ形
            addOval(androidx.compose.ui.geometry.Rect(cx - r * 0.85f, cy - r * 0.5f, cx - r * 0.05f, cy + r * 0.3f))
            addOval(androidx.compose.ui.geometry.Rect(cx + r * 0.05f, cy - r * 0.5f, cx + r * 0.85f, cy + r * 0.3f))
            addOval(androidx.compose.ui.geometry.Rect(cx - r * 0.55f, cy - r * 0.9f, cx + r * 0.55f, cy + r * 0.2f))
            addOval(androidx.compose.ui.geometry.Rect(cx - r * 0.45f, cy + r * 0.1f, cx + r * 0.45f, cy + r * 0.95f))
        }
        CellColor.BLUE -> {
            // 雫（涙形）
            moveTo(cx, cy - r * 0.95f)
            cubicTo(
                cx + r * 0.9f, cy - r * 0.15f,
                cx + r * 0.7f, cy + r * 0.9f,
                cx, cy + r * 0.9f,
            )
            cubicTo(
                cx - r * 0.7f, cy + r * 0.9f,
                cx - r * 0.9f, cy - r * 0.15f,
                cx, cy - r * 0.95f,
            )
            close()
        }
        CellColor.YELLOW -> {
            // 5 星
            val outer = r * 0.95f
            val inner = r * 0.42f
            val start = -PI / 2
            for (i in 0 until 10) {
                val rr = if (i % 2 == 0) outer else inner
                val a = start + i * PI / 5
                val x = cx + (cos(a) * rr).toFloat()
                val y = cy + (sin(a) * rr).toFloat()
                if (i == 0) moveTo(x, y) else lineTo(x, y)
            }
            close()
        }
        CellColor.PURPLE -> {
            // 三日月（大円 - 小円）
            val bigR = r * 0.9f
            addOval(androidx.compose.ui.geometry.Rect(cx - bigR, cy - bigR, cx + bigR, cy + bigR))
            // "cut" by subtracting a smaller circle offset to the right — Compose Path doesn't have
            // easy boolean ops, so approximate with an inner white overlay drawn on top.
        }
        CellColor.OJAMA -> {
            // 角丸四角
            val rr = r * 0.85f
            addRoundRect(
                androidx.compose.ui.geometry.RoundRect(
                    cx - rr, cy - rr, cx + rr, cy + rr,
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(r * 0.25f)
                )
            )
        }
    }
}

/** 中央アイコン overlay（各色の識別性を高める微小シンボル）。 */
private fun DrawScope.drawIconOverlay(color: CellColor, cx: Float, cy: Float, d: Float) {
    when (color) {
        CellColor.PURPLE -> {
            // 三日月の欠け部分を背景色でくり抜く（右下寄せの円）
            val bg = Color(0xFF2A1B4E) // プレイ背景と同色寄りの暗紫
            drawCircle(
                color = bg,
                radius = d * 0.36f,
                center = Offset(cx + d * 0.16f, cy - d * 0.06f),
            )
        }
        CellColor.OJAMA -> {
            // × マーク
            val stroke = d * 0.06f
            val arm = d * 0.24f
            drawLine(
                color = Color(0xFFCCCCCC),
                start = Offset(cx - arm, cy - arm),
                end = Offset(cx + arm, cy + arm),
                strokeWidth = stroke,
            )
            drawLine(
                color = Color(0xFFCCCCCC),
                start = Offset(cx + arm, cy - arm),
                end = Offset(cx - arm, cy + arm),
                strokeWidth = stroke,
            )
        }
        CellColor.GREEN -> {
            // 茎（縦線）
            drawLine(
                color = Color(0xFF0F4514),
                start = Offset(cx, cy + d * 0.15f),
                end = Offset(cx, cy + d * 0.42f),
                strokeWidth = d * 0.055f,
            )
        }
        else -> { /* nothing */ }
    }
}
