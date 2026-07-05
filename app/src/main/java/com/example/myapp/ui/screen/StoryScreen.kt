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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapp.App
import com.example.myapp.data.local.entity.StoryProgressEntity
import com.example.myapp.domain.model.CharacterVariant
import com.example.myapp.ui.component.CharacterImage
import kotlinx.coroutines.launch

/**
 * ストーリーモード（会話 → バトル）。設計書: docs/設計/features/ストーリーモード.md
 *
 * デザイン: ビジュアルノベル風。フル画面キャラ立ち絵（variant 変化）+
 * 下部に半透明の台詞窓。話者名は上部バッジ。「次へ」は右下の派手なボタン。
 */
@Composable
fun StoryScreen(characterId: String, chapter: Int = 1, onChapterClear: () -> Unit, onGameOver: (Long, Int, String) -> Unit) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val scope = rememberCoroutineScope()
    val dialogs = remember(characterId, chapter) { StoryDialogs.get(characterId, chapter) }
    val winRequirement = remember(chapter) { StoryDialogs.winRequirement(chapter) }
    var index by remember { mutableIntStateOf(0) }
    var inBattle by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler {
        // 会話中の戻る: タイトルへ戻る（バトル中は EndlessScreen 内で拾われる）
        onGameOver(0L, 0, characterId)
    }

    LaunchedEffect(Unit) { app.audio.playBgm("story_dialog") }
    // 台詞ごとに個別ボイスを再生（story_ch<章>_<index>.ogg）。
    // 会話中のみ再生し、バトル遷移後は playVoice が中断・停止される。
    LaunchedEffect(index, inBattle) {
        if (!inBattle && index < dialogs.size) {
            app.audio.playVoice(characterId, "story_ch${chapter}_$index")
        }
    }

    if (!inBattle) {
        val infinite = rememberInfiniteTransition(label = "story-breath")
        val breath by infinite.animateFloat(
            1f, 1.05f,
            infiniteRepeatable(tween(3000, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
            label = "breath",
        )
        val d = dialogs[index]
        Box(
            modifier = Modifier.fillMaxSize()
                .background(Brush.verticalGradient(listOf(Color(0xFF1A0F2E), Color(0xFF3A1B5E))))
                .testTag("story_root"),
        ) {
            // 全画面キャラ立ち絵
            CharacterImage(
                characterId = characterId,
                variant = d.variant,
                modifier = Modifier.fillMaxSize().scale(breath).alpha(0.85f),
                contentScale = ContentScale.Crop,
                fallbackLabel = "",
            )
            // 上下 vignette
            Box(modifier = Modifier.fillMaxSize().background(
                Brush.verticalGradient(listOf(Color(0x881A0F2E), Color(0x001A0F2E), Color(0xCC1A0F2E)))
            ))
            // 章タイトル（上部）
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0xCC000000)),
                shape = RoundedCornerShape(bottomStart = 20.dp, bottomEnd = 20.dp),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 40.dp),
            ) {
                Text("第 $chapter 章 : ${characterId}",
                    fontSize = 14.sp, fontWeight = FontWeight.Bold,
                    color = Color(0xFFFFC22E), textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp).testTag("story_chapter_title"),
                )
            }
            // 話者名バッジ + 台詞窓（下部）
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp).align(Alignment.BottomCenter),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFF6FA8)),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.height(32.dp).padding(start = 8.dp),
                ) {
                    Box(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp), contentAlignment = Alignment.Center) {
                        Text(d.speaker,
                            fontSize = 13.sp, fontWeight = FontWeight.Bold, color = Color.White,
                            modifier = Modifier.testTag("story_speaker_name"),
                        )
                    }
                }
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xEE000000)),
                    shape = RoundedCornerShape(18.dp),
                    modifier = Modifier.fillMaxWidth().height(120.dp),
                ) {
                    Text(d.text,
                        fontSize = 18.sp, color = Color.White,
                        modifier = Modifier.fillMaxSize().padding(20.dp).testTag("story_dialog_text"),
                    )
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0x99000000)),
                        shape = RoundedCornerShape(20.dp),
                        modifier = Modifier.weight(1f).height(48.dp).clickable { /* ログは省略 */ }
                            .testTag("story_log_button"),
                    ) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("📜 ログ", fontSize = 13.sp, color = Color(0xFF00E5FF), fontWeight = FontWeight.Bold)
                        }
                    }
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
                        shape = RoundedCornerShape(20.dp),
                        modifier = Modifier.weight(2f).height(48.dp)
                            .background(Brush.horizontalGradient(listOf(Color(0xFFFF6FA8), Color(0xFF7C4DFF))), RoundedCornerShape(20.dp))
                            .clickable {
                                // index を進めるだけで、ボイスは LaunchedEffect(index) が再生。
                                if (index + 1 < dialogs.size) index += 1 else inBattle = true
                            }
                            .testTag("story_next_button"),
                    ) {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text(if (index + 1 < dialogs.size) "次へ ▶" else "バトル開始 ⚔️",
                                fontSize = 14.sp, fontWeight = FontWeight.Black, color = Color.White,
                            )
                        }
                    }
                }
            }
        }
    } else {
        EndlessScreen(onGameOver = { score, maxChain, char ->
            if (score >= winRequirement) {
                scope.launch {
                    app.db.storyProgressDao().upsert(
                        StoryProgressEntity(id = characterId, clearedChapter = chapter, updatedAt = System.currentTimeMillis())
                    )
                    onChapterClear()
                }
            } else {
                onGameOver(score, maxChain, char)
            }
        }, rootTag = "story_root")
    }
}
