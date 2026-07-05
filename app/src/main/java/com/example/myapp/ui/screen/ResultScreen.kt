package com.example.myapp.ui.screen

import android.app.Activity
import android.content.Intent
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapp.App
import com.example.myapp.data.local.entity.HighScoreEntity
import com.example.myapp.domain.model.CharacterVariant
import com.example.myapp.ui.component.CharacterImage
import com.example.myapp.ui.component.CharacterModal
import com.example.myapp.util.CharacterDisplay

/**
 * リザルト / ゲームオーバー画面。設計書: docs/設計/features/リザルト_ゲームオーバー.md
 *
 * 演出:
 *  - rank に応じて victory / joy / normal / lose variant を大きく表示
 *  - TOP 3 は金枠バナー + キラキラ pulse
 *  - スコア/連鎖数は Card レイヤーで rounded 表示
 */
@Composable
fun ResultScreen(
    mode: String,
    score: Long,
    maxChain: Int,
    characterId: String,
    onRetry: () -> Unit,
    onBackToTitle: () -> Unit,
) {
    val ctx = LocalContext.current
    val view = LocalView.current
    val app = ctx.applicationContext as App
    var rank by remember { mutableIntStateOf(-1) }
    var modalOpen by remember { mutableStateOf(false) }

    LaunchedEffect(mode, score, maxChain, characterId) {
        try {
            if (score > 0 || maxChain > 0) {
                val dao = app.db.highScoreDao()
                val now = System.currentTimeMillis()
                dao.insert(HighScoreEntity(mode = mode, score = score, maxChain = maxChain,
                    characterId = characterId, playedAt = now))
                val top10 = dao.top10(mode)
                rank = top10.indexOfFirst {
                    it.score == score && it.characterId == characterId && it.playedAt == now
                } + 1
            }
            app.audio.playBgm(if (score > 0) "result_win" else "result_lose")
            // 勝利/敗北ボイス
            app.audio.playVoice(characterId, if (score > 0) "win" else "lose")
        } catch (_: Exception) { /* 失敗は黙殺 */ }
    }

    val variant = when {
        rank in 1..3 -> CharacterVariant.VICTORY  // TOP3 は勝ちポーズ
        rank in 4..10 -> CharacterVariant.JOY
        score == 0L -> CharacterVariant.LOSE
        maxChain >= 5 -> CharacterVariant.BIG_CHAIN
        maxChain >= 2 -> CharacterVariant.WINK    // 2連鎖以上はウインクで小さな勝利感
        else -> CharacterVariant.NORMAL
    }

    // TOP3 のときはキラキラ pulse
    val transition = rememberInfiniteTransition(label = "result-shine")
    val shine by transition.animateFloat(
        1f, 1.06f,
        infiniteRepeatable(tween(700, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "shine",
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF1A0F2E), Color(0xFF2A1B4E), Color(0xFF1A0F2E))))
            .testTag("result_root"),
    ) {
        // 背景: キャラ立ち絵を半透明で敷く
        CharacterImage(
            characterId = characterId,
            variant = variant,
            modifier = Modifier.fillMaxSize().scale(1.1f * (if (rank in 1..3) shine else 1f)),
            contentScale = ContentScale.Crop,
            fallbackLabel = "",
        )
        Box(modifier = Modifier.fillMaxSize().background(
            Brush.verticalGradient(listOf(Color(0xEE1A0F2E), Color(0x991A0F2E), Color(0xEE1A0F2E)))
        ))

        Column(
            modifier = Modifier.fillMaxSize().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                if (score > 0) "RESULT" else "GAME OVER",
                fontSize = 34.sp, fontWeight = FontWeight.Black,
                color = if (score > 0) Color(0xFFFFC22E) else Color(0xFFAAAAAA),
            )
            // Character showcase（300dp / タップで拡大）
            Box(
                modifier = Modifier.fillMaxWidth().height(300.dp)
                    .clickable { modalOpen = true }
                    .testTag("result_character_image"),
                contentAlignment = Alignment.Center,
            ) {
                CharacterImage(
                    characterId = characterId,
                    variant = variant,
                    modifier = Modifier.fillMaxSize().scale(if (rank in 1..3) shine else 1f),
                    fallbackLabel = "[$characterId]",
                )
                Box(
                    modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp)
                        .background(Color(0xAA000000), RoundedCornerShape(12.dp))
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text("🔍 タップで拡大", fontSize = 10.sp, color = Color(0xFF00E5FF))
                }
            }
            // Score card
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0x99000000)),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("SCORE", fontSize = 12.sp, color = Color(0xFF00E5FF))
                    Text("$score",
                        fontSize = 44.sp, fontWeight = FontWeight.Black,
                        color = Color.White,
                        modifier = Modifier.testTag("result_score_text"))
                    Text("MAX CHAIN: $maxChain",
                        fontSize = 16.sp, fontWeight = FontWeight.Bold,
                        color = Color(0xFFFFC22E),
                        modifier = Modifier.testTag("result_max_chain_text"))
                }
            }
            if (rank in 1..10) {
                Card(
                    colors = CardDefaults.cardColors(
                        containerColor = if (rank in 1..3) Color(0xFFFFD700) else Color(0xFF7C4DFF),
                    ),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp)
                        .scale(if (rank in 1..3) shine else 1f)
                        .testTag("result_topten_banner"),
                ) {
                    Text(
                        "🏆 TOP $rank 入り！",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Black,
                        color = if (rank in 1..3) Color(0xFF1A0F2E) else Color.White,
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    )
                }
            }
            // Actions
            ResultBtn("シェア", "result_share_button", Color(0xFF00E5FF)) {
                try {
                    val intent = app.screenCapture.captureAndCreateShareIntent(view, "プリズマ☆リンク")
                    (ctx as? Activity)?.startActivity(Intent.createChooser(intent, "シェア"))
                } catch (_: Exception) { }
            }
            ResultBtn("もう一度", "result_retry_button", Color(0xFFFF6FA8)) { onRetry() }
            ResultBtn("タイトルへ", "result_back_to_title_button", Color(0xFF7C4DFF)) { onBackToTitle() }
        }
        if (modalOpen) {
            CharacterModal(
                characterId = characterId,
                variant = variant,
                displayName = CharacterDisplay.displayName(characterId),
                onDismiss = { modalOpen = false },
            )
        }
    }
}

@Composable
private fun ResultBtn(label: String, tag: String, color: Color, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(containerColor = color),
        shape = RoundedCornerShape(28.dp),
        modifier = Modifier.fillMaxWidth().height(52.dp).testTag(tag),
    ) { Text(label, fontWeight = FontWeight.Bold, fontSize = 16.sp) }
}
