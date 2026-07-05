package com.example.myapp.ui.screen

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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.LaunchedEffect
import com.example.myapp.App
import com.example.myapp.audio.AudioCue
import kotlinx.coroutines.flow.first

/**
 * ゲームモード選択。設計書: docs/設計/features/ゲームモード選択.md
 */
@Composable
fun ModeSelectScreen(
    onEndless: () -> Unit,
    onScoreAttack: () -> Unit,
    onStory: () -> Unit,
    onCpu: () -> Unit,
    onBack: () -> Unit,
) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val tap = { app.audio.play(AudioCue.Se("button_tap")) }
    var focused by remember { mutableStateOf<String?>(null) }
    // ストーリー進行状況の破損検知
    var storyCorrupt by remember { mutableStateOf(false) }
    var pendingStory by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        try {
            val progList = app.db.storyProgressDao().observeAll().first()
            storyCorrupt = progList.any { p ->
                p.clearedChapter < 0 || p.clearedChapter > StoryDialogs.maxChapters()
            }
        } catch (_: Exception) { storyCorrupt = false }
    }
    androidx.activity.compose.BackHandler { onBack() }

    Box(
        modifier = Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF1A0F2E), Color(0xFF2A1B4E), Color(0xFF1A0F2E))))
            .testTag("mode_select_root"),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("モード選択",
                fontSize = 28.sp, fontWeight = FontWeight.Black, color = Color.White,
                modifier = Modifier.padding(bottom = 4.dp),
            )
            Text("お好きな遊び方を選んでね ✨",
                fontSize = 13.sp, color = Color(0xFF00E5FF),
                modifier = Modifier.testTag("mode_description_text").padding(bottom = 12.dp),
            )
            ModeCard(
                id = "endless", icon = "♾️", title = "エンドレス",
                subtitle = "終わりなき挑戦",
                desc = "ゲームオーバーまで無限に連鎖を組もう",
                gradient = listOf(Color(0xFFFF6FA8), Color(0xFF7C4DFF)),
                focused = focused == "endless",
                onFocus = { focused = "endless" },
                onClick = { tap(); onEndless() },
                tag = "mode_endless_button",
            )
            ModeCard(
                id = "sa", icon = "⏱️", title = "スコアアタック",
                subtitle = "3 分間の勝負",
                desc = "制限時間内でハイスコアを狙え！",
                gradient = listOf(Color(0xFFFFC22E), Color(0xFFFF6FA8)),
                focused = focused == "sa",
                onFocus = { focused = "sa" },
                onClick = { tap(); onScoreAttack() },
                tag = "mode_scoreattack_button",
            )
            ModeCard(
                id = "story", icon = "📖", title = "ストーリー",
                subtitle = "キャラと物語を紡ぐ",
                desc = "会話とバトルの短編シナリオ",
                gradient = listOf(Color(0xFF00E5FF), Color(0xFF7C4DFF)),
                focused = focused == "story",
                onFocus = { focused = "story" },
                onClick = {
                    tap()
                    if (storyCorrupt) pendingStory = true else onStory()
                },
                tag = "mode_story_button",
            )
            ModeCard(
                id = "cpu", icon = "🤖", title = "CPU 対戦",
                subtitle = "AI と真剣勝負",
                desc = "連鎖でおじゃまぷよを送り込め！",
                gradient = listOf(Color(0xFFDC143C), Color(0xFF9B47DB)),
                focused = focused == "cpu",
                onFocus = { focused = "cpu" },
                onClick = { tap(); onCpu() },
                tag = "mode_cpu_button",
            )
            BackBtn(onClick = { tap(); onBack() })
        }
        if (pendingStory) {
            androidx.compose.material3.AlertDialog(
                modifier = Modifier.testTag("mode_story_warning_dialog"),
                onDismissRequest = { pendingStory = false },
                title = { Text("ストーリー進行状況が破損しています") },
                text = { Text("記録が読み取れませんでした。第 1 章から再開しますか？") },
                confirmButton = {
                    androidx.compose.material3.TextButton(onClick = {
                        pendingStory = false
                        storyCorrupt = false
                        onStory()
                    }) { Text("第 1 章から", color = Color(0xFFFFC22E), fontWeight = FontWeight.Bold) }
                },
                dismissButton = {
                    androidx.compose.material3.TextButton(onClick = { pendingStory = false }) {
                        Text("キャンセル")
                    }
                },
            )
        }
    }
}

@Composable
private fun ModeCard(
    id: String, icon: String, title: String, subtitle: String, desc: String,
    gradient: List<Color>, focused: Boolean,
    onFocus: () -> Unit, onClick: () -> Unit, tag: String,
) {
    val transition = rememberInfiniteTransition(label = "card-$id")
    val pulse by transition.animateFloat(
        1f, 1.03f,
        infiniteRepeatable(tween(1200, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "card-pulse-$id",
    )
    Card(
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        shape = RoundedCornerShape(20.dp),
        modifier = Modifier
            .fillMaxWidth()
            .height(88.dp)
            .scale(if (focused) pulse else 1f)
            .background(Brush.horizontalGradient(gradient), RoundedCornerShape(20.dp))
            .clickable { onFocus(); onClick() }
            .testTag(tag),
    ) {
        Row(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(icon, fontSize = 40.sp, modifier = Modifier.padding(end = 16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, fontSize = 22.sp, fontWeight = FontWeight.Black, color = Color.White)
                Text(subtitle, fontSize = 11.sp, color = Color(0xFFFFE680), fontWeight = FontWeight.Bold)
                Text(desc, fontSize = 11.sp, color = Color.White.copy(alpha = 0.85f))
            }
            Text("▶", fontSize = 22.sp, color = Color.White)
        }
    }
}

@Composable
private fun BackBtn(onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xAA000000)),
        shape = RoundedCornerShape(24.dp),
        modifier = Modifier.fillMaxWidth().height(48.dp).clickable { onClick() }.testTag("mode_back_button"),
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("← タイトルへ戻る", fontSize = 14.sp, color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}
