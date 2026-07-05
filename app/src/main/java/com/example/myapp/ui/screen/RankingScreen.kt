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
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapp.App
import com.example.myapp.data.local.entity.HighScoreEntity
import com.example.myapp.domain.model.CharacterVariant
import com.example.myapp.ui.component.CharacterImage
import com.example.myapp.ui.component.CharacterModal
import com.example.myapp.util.CharacterDisplay

/**
 * ローカルランキング画面。設計書: docs/設計/features/ローカルランキング.md
 *
 * デザイン: TOP3 を表彰台風レイアウトで大きく強調（キャラアイコン最大 100dp）、
 * 4-10 位を LazyColumn カード（56dp アイコン）で表示。
 * キャラアイコン tap でモーダル拡大表示。
 */
@Composable
fun RankingScreen(initialMode: String = "endless", onBack: () -> Unit) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    var mode by remember { mutableStateOf(initialMode) }
    val rows by app.db.highScoreDao().observeTop10(mode).collectAsState(initial = emptyList())
    androidx.activity.compose.BackHandler { onBack() }
    var modalOpen by remember { mutableStateOf<Pair<String, CharacterVariant>?>(null) }

    Box(
        modifier = Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF1A0F2E), Color(0xFF2A1B4E), Color(0xFF1A0F2E))))
            .testTag("ranking_root"),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("🏆 ランキング TOP10",
                fontSize = 26.sp, fontWeight = FontWeight.Black,
                color = Color(0xFFFFD700),
            )
            ModeTabs(current = mode, onSelect = { mode = it })
            if (rows.isEmpty()) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0x66000000)),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth().padding(top = 24.dp),
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text("📭", fontSize = 44.sp)
                        Text("まだ記録がありません",
                            fontSize = 16.sp, color = Color.White,
                            modifier = Modifier.testTag("ranking_empty_text"),
                        )
                        Text("プレイしてハイスコアを刻もう！",
                            fontSize = 11.sp, color = Color(0xFFB0B0C0),
                        )
                    }
                }
            } else {
                Podium(
                    rows = rows.take(3),
                    onCharacterClick = { id, variant -> modalOpen = id to variant },
                )
                Spacer(modifier = Modifier.height(4.dp))
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().weight(1f).testTag("ranking_list"),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    itemsIndexed(rows.drop(3), key = { _, r -> r.id }) { idx, row ->
                        LowerRankRow(
                            rank = idx + 4, row = row,
                            onCharacterClick = { modalOpen = row.characterId to CharacterVariant.NORMAL },
                        )
                    }
                }
            }
            BackBtnRanking(onClick = onBack)
        }
        modalOpen?.let { (id, variant) ->
            CharacterModal(
                characterId = id,
                variant = variant,
                displayName = CharacterDisplay.displayName(id),
                onDismiss = { modalOpen = null },
            )
        }
    }
}

@Composable
private fun ModeTabs(current: String, onSelect: (String) -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        TabBtn("ENDLESS", "endless", current, "ranking_tab_endless", onSelect, Modifier.weight(1f))
        TabBtn("SCORE ATK", "scoreAttack", current, "ranking_tab_scoreattack", onSelect, Modifier.weight(1f))
        TabBtn("CPU", "cpuBattle", current, "ranking_tab_cpu", onSelect, Modifier.weight(1f))
    }
}

@Composable
private fun TabBtn(label: String, value: String, current: String, tag: String, onSelect: (String) -> Unit, modifier: Modifier) {
    val active = current == value
    Card(
        colors = CardDefaults.cardColors(
            containerColor = if (active) Color(0xFF00E5FF) else Color(0x66000000),
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.height(38.dp).clickable { onSelect(value) }.testTag(tag),
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(label, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                color = if (active) Color(0xFF1A0F2E) else Color.White,
            )
        }
    }
}

@Composable
private fun Podium(rows: List<HighScoreEntity>, onCharacterClick: (String, CharacterVariant) -> Unit) {
    val transition = rememberInfiniteTransition(label = "podium-shine")
    val shine by transition.animateFloat(
        1f, 1.05f,
        infiniteRepeatable(tween(900, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "shine",
    )
    Row(
        modifier = Modifier.fillMaxWidth().height(260.dp),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (rows.size >= 2) PodiumCard(2, rows[1], 200.dp, Color(0xFFC0C0C0), shine, onCharacterClick, Modifier.weight(1f))
        else Spacer(modifier = Modifier.weight(1f))
        if (rows.size >= 1) PodiumCard(1, rows[0], 260.dp, Color(0xFFFFD700), shine, onCharacterClick, Modifier.weight(1f))
        else Spacer(modifier = Modifier.weight(1f))
        if (rows.size >= 3) PodiumCard(3, rows[2], 170.dp, Color(0xFFCD7F32), shine, onCharacterClick, Modifier.weight(1f))
        else Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun PodiumCard(
    rank: Int, row: HighScoreEntity, heightDp: androidx.compose.ui.unit.Dp,
    medalColor: Color, shine: Float,
    onCharacterClick: (String, CharacterVariant) -> Unit,
    modifier: Modifier,
) {
    val medal = when (rank) { 1 -> "🥇"; 2 -> "🥈"; else -> "🥉" }
    val variant = if (rank == 1) CharacterVariant.VICTORY else CharacterVariant.JOY
    val portraitSize = if (rank == 1) 110.dp else 78.dp
    Card(
        colors = CardDefaults.cardColors(containerColor = medalColor.copy(alpha = 0.92f)),
        shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp, bottomStart = 8.dp, bottomEnd = 8.dp),
        modifier = modifier.height(heightDp).scale(if (rank == 1) shine else 1f)
            .testTag("ranking_row_$rank"),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(medal, fontSize = 20.sp)
            Box(
                modifier = Modifier.size(portraitSize)
                    .background(Color(0x33000000), CircleShape)
                    .clickable { onCharacterClick(row.characterId, variant) },
            ) {
                CharacterImage(
                    characterId = row.characterId,
                    variant = variant,
                    modifier = Modifier.fillMaxSize(),
                    fallbackLabel = "",
                )
            }
            Text("${row.score}",
                fontSize = 14.sp, fontWeight = FontWeight.Black, color = Color(0xFF1A0F2E),
            )
            Text("${row.maxChain}連",
                fontSize = 10.sp, color = Color(0xFF1A0F2E),
            )
            Text(row.characterId,
                fontSize = 9.sp, color = Color(0xFF1A0F2E),
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

@Composable
private fun LowerRankRow(rank: Int, row: HighScoreEntity, onCharacterClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0x66000000)),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.fillMaxWidth().testTag("ranking_row_$rank"),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("#$rank", fontSize = 14.sp, color = Color(0xFF00E5FF),
                fontWeight = FontWeight.Bold,
                modifier = Modifier.width(36.dp),
            )
            Box(
                modifier = Modifier.size(56.dp)
                    .background(Color(0x33000000), CircleShape)
                    .clickable { onCharacterClick() },
            ) {
                CharacterImage(
                    characterId = row.characterId,
                    variant = CharacterVariant.NORMAL,
                    modifier = Modifier.fillMaxSize(),
                    fallbackLabel = "",
                )
            }
            Text("${row.score}", fontSize = 18.sp, fontWeight = FontWeight.Black, color = Color.White,
                modifier = Modifier.weight(1f).padding(start = 8.dp))
            Text("${row.maxChain}連", fontSize = 12.sp, color = Color(0xFFFFC22E), modifier = Modifier.width(50.dp))
            Text(row.characterId, fontSize = 11.sp, color = Color(0xFFFFB3D9),
                modifier = Modifier.width(52.dp),
                textAlign = TextAlign.End,
            )
        }
    }
}

@Composable
private fun BackBtnRanking(onClick: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xAA000000)),
        shape = RoundedCornerShape(24.dp),
        modifier = Modifier.fillMaxWidth().height(48.dp).clickable { onClick() }.testTag("ranking_back_button"),
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("← タイトルへ戻る", fontSize = 14.sp, color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}
