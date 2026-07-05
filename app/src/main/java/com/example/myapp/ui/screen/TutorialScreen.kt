package com.example.myapp.ui.screen

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapp.App
import com.example.myapp.domain.game.CellColor
import com.example.myapp.ui.component.PuyoOrb
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * 任意チュートリアル。設計書: docs/設計/features/任意チュートリアル.md
 *
 * デザイン: 各ページに絵文字/PuyoOrb デモを大きく配置。上部にページインジケータ、
 * 下部にとばす/次への gradient ボタン。
 */
private data class TutorialPage(val title: String, val body: String, val demo: Demo)
private enum class Demo { TAP_ROTATE, DRAG_MOVE, CHAIN, SKILL, SWIPE_DOWN }

private val PAGES = listOf(
    TutorialPage("画面をタップで回転", "ブロックをタップすると時計回りに回転します。狙った向きに素早く合わせよう！", Demo.TAP_ROTATE),
    TutorialPage("ドラッグで横移動", "画面を左右にドラッグするとブロックが左右に動きます。ボタンでも操作可能。", Demo.DRAG_MOVE),
    TutorialPage("同色 3 つで消える", "同じ色のブロックを 3 つ以上つなげると消えて、上のブロックが落ちてきます。", Demo.CHAIN),
    TutorialPage("下にスワイプで即着地", "画面を素早く下にスワイプするとブロックが一気に着地します。", Demo.SWIPE_DOWN),
    TutorialPage("必殺技で大逆転", "連鎖でゲージが溜まったら「発動」ボタンで必殺技！キャラごとに違う効果を試そう。", Demo.SKILL),
)

@Composable
fun TutorialScreen(onDone: () -> Unit) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val scope = rememberCoroutineScope()
    var page by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        page = (app.settings.settings.first().tutorialLastViewedPage).coerceIn(0, PAGES.size - 1)
    }
    androidx.activity.compose.BackHandler { onDone() }

    Box(
        modifier = Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF1A0F2E), Color(0xFF2A1B4E), Color(0xFF1A0F2E))))
            .testTag("tutorial_root"),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // ページインジケータ（ドット）
            Row(
                modifier = Modifier.fillMaxWidth().testTag("tutorial_page_indicator"),
                horizontalArrangement = Arrangement.Center,
            ) {
                PAGES.indices.forEach { i ->
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 4.dp)
                            .size(if (i == page) 12.dp else 8.dp)
                            .background(
                                color = if (i == page) Color(0xFFFF6FA8) else Color(0x66FFFFFF),
                                shape = CircleShape,
                            ),
                    )
                }
            }
            Text("${page + 1} / ${PAGES.size}",
                fontSize = 11.sp, color = Color(0xFF00E5FF),
                modifier = Modifier.fillMaxWidth(),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            // タイトル
            Text(PAGES[page].title,
                fontSize = 24.sp, fontWeight = FontWeight.Black, color = Color(0xFFFFC22E),
                modifier = Modifier.fillMaxWidth(),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            // デモ領域
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0x66000000)),
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier.fillMaxWidth().weight(1f).testTag("tutorial_demo_area"),
            ) {
                DemoContent(PAGES[page].demo)
            }
            // 本文
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0x88000000)),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth().testTag("tutorial_text_area"),
            ) {
                Text(PAGES[page].body,
                    fontSize = 15.sp, color = Color.White,
                    modifier = Modifier.padding(16.dp),
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0x99000000)),
                    shape = RoundedCornerShape(24.dp),
                    modifier = Modifier.weight(1f).height(52.dp).clickable {
                        scope.launch { app.settings.setTutorialLastViewedPage(0); onDone() }
                    }.testTag("tutorial_skip_button"),
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("とばす", fontSize = 14.sp, color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color.Transparent),
                    shape = RoundedCornerShape(24.dp),
                    modifier = Modifier.weight(2f).height(52.dp)
                        .background(Brush.horizontalGradient(listOf(Color(0xFFFF6FA8), Color(0xFF7C4DFF))), RoundedCornerShape(24.dp))
                        .clickable {
                            scope.launch {
                                if (page + 1 >= PAGES.size) {
                                    app.settings.setTutorialLastViewedPage(0); onDone()
                                } else {
                                    page += 1; app.settings.setTutorialLastViewedPage(page)
                                }
                            }
                        }.testTag("tutorial_next_button"),
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(if (page + 1 >= PAGES.size) "完了 ✨" else "次へ ▶",
                            fontSize = 15.sp, color = Color.White, fontWeight = FontWeight.Black,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DemoContent(demo: Demo) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        when (demo) {
            Demo.TAP_ROTATE -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("👆", fontSize = 60.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.size(50.dp)) { PuyoOrb(CellColor.RED, Modifier.fillMaxSize()) }
                    Text("🔄", fontSize = 30.sp)
                    Box(Modifier.size(50.dp)) { PuyoOrb(CellColor.YELLOW, Modifier.fillMaxSize()) }
                }
                Text("タップで CW 回転", fontSize = 12.sp, color = Color(0xFFFFC22E))
            }
            Demo.DRAG_MOVE -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("← 👉 →", fontSize = 48.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.size(50.dp)) { PuyoOrb(CellColor.BLUE, Modifier.fillMaxSize()) }
                    Box(Modifier.size(50.dp)) { PuyoOrb(CellColor.GREEN, Modifier.fillMaxSize()) }
                }
                Text("ドラッグで横移動", fontSize = 12.sp, color = Color(0xFFFFC22E))
            }
            Demo.CHAIN -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                repeat(4) { Box(Modifier.size(50.dp)) { PuyoOrb(CellColor.PURPLE, Modifier.fillMaxSize()) } }
            }
            Demo.SWIPE_DOWN -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("👇", fontSize = 60.sp)
                Box(Modifier.size(50.dp)) { PuyoOrb(CellColor.YELLOW, Modifier.fillMaxSize()) }
                Text("下スワイプで即着地", fontSize = 12.sp, color = Color(0xFFFFC22E))
            }
            Demo.SKILL -> Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("✨💥✨", fontSize = 44.sp)
                Text("必殺技 発動！", fontSize = 22.sp, fontWeight = FontWeight.Black, color = Color(0xFFFFD700))
            }
        }
    }
}
