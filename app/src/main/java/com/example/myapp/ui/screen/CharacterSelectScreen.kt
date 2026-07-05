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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import com.example.myapp.audio.AudioCue
import com.example.myapp.domain.model.CharacterVariant
import com.example.myapp.ui.component.CharacterImage
import com.example.myapp.ui.component.CharacterModal
import kotlinx.coroutines.launch

/**
 * キャラクター選択。設計書: docs/設計/features/キャラクター選択.md
 *
 * デザイン: 上半分にキャラ立ち絵の大プレビュー、下半分にキャラカード横スクロール。
 * 選択中カードにはネオン枠 + pulse animation。カードは各キャラの color_accent で個性を演出。
 */
@Composable
fun CharacterSelectScreen(onConfirm: () -> Unit) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val scope = rememberCoroutineScope()
    androidx.activity.compose.BackHandler { onConfirm() }
    // モーダル拡大表示
    var modalOpen by remember { mutableStateOf<Pair<String, CharacterVariant>?>(null) }
    val settings by app.settings.settings.collectAsState(initial = com.example.myapp.settings.AppSettings())
    val characters by app.characterRepo.observe().collectAsState(initial = emptyList())
    var selected by remember { mutableStateOf(settings.selectedCharacterId) }

    // 立ち絵の呼吸アニメ
    val infinite = rememberInfiniteTransition(label = "char-breath")
    val breath by infinite.animateFloat(
        1.0f, 1.04f,
        infiniteRepeatable(tween(2400, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "breath",
    )

    Box(
        modifier = Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF1A0F2E), Color(0xFF2A1B4E), Color(0xFF1A0F2E))))
            .testTag("character_select_root"),
    ) {
        // 背景に選択中キャラのぼんやりオーラ
        CharacterImage(
            characterId = selected,
            variant = CharacterVariant.NORMAL,
            modifier = Modifier.fillMaxSize().alpha(0.14f).scale(1.3f),
            contentScale = ContentScale.Crop,
            fallbackLabel = "",
        )
        Box(modifier = Modifier.fillMaxSize().background(
            Brush.verticalGradient(listOf(Color(0xEE1A0F2E), Color(0x881A0F2E), Color(0xEE1A0F2E)))
        ))

        Column(
            modifier = Modifier.fillMaxSize()
                .padding(top = 40.dp, start = 16.dp, end = 16.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("キャラクター選択",
                fontSize = 22.sp, fontWeight = FontWeight.Black,
                color = Color.White,
            )
            // 大プレビュー: weight(1f) で残余全てを占有（スクロールなしで全要素表示）
            val current = characters.firstOrNull { it.id == selected }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f, fill = true)
                    .clickable { modalOpen = selected to CharacterVariant.NORMAL }
                    .testTag("character_preview_image"),
                contentAlignment = Alignment.Center,
            ) {
                CharacterImage(
                    characterId = selected,
                    variant = CharacterVariant.NORMAL,
                    modifier = Modifier.fillMaxSize().scale(breath),
                    fallbackLabel = current?.displayName ?: selected,
                )
                // 「タップで拡大」ヒント
                Box(
                    modifier = Modifier.align(Alignment.BottomEnd).padding(8.dp)
                        .background(Color(0xAA000000), androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text("🔍 タップで拡大", fontSize = 10.sp, color = Color(0xFF00E5FF))
                }
            }
            // 名前 + ボイスプレビュー (コンパクト化: height 40dp)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(current?.displayName ?: selected,
                        fontSize = 24.sp, fontWeight = FontWeight.Black,
                        color = Color(0xFFFFC22E),
                    )
                }
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFF00E5FF)),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.height(40.dp)
                        .clickable { app.audio.play(AudioCue.Voice(selected, "select_preview")) }
                        .testTag("character_voice_preview_button"),
                ) {
                    Box(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp), contentAlignment = Alignment.Center) {
                        Text("🎤 ボイス試聴", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1A0F2E))
                    }
                }
            }
            // スキル情報カード (コンパクト化)
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0xAA000000)),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("⚡", fontSize = 16.sp)
                        Text("必殺技: ${characterSkillName(selected)}",
                            fontSize = 13.sp, fontWeight = FontWeight.Bold,
                            color = Color(0xFFFFC22E),
                            modifier = Modifier.padding(start = 6.dp),
                        )
                    }
                    Text(characterSkillDesc(selected),
                        fontSize = 10.sp, color = Color(0xFFB0F0FF),
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
            // キャラカード横スクロール (高さ縮小)
            LazyRow(
                modifier = Modifier.fillMaxWidth().testTag("character_list"),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(characters, key = { it.id }) { c ->
                    CharCard(
                        characterId = c.id,
                        displayName = c.displayName,
                        selected = c.id == selected,
                        onClick = {
                            selected = c.id
                            app.audio.play(AudioCue.Voice(c.id, "select_preview"))
                        },
                    )
                }
            }
            // 決定ボタン (高さ縮小)
            Card(
                colors = CardDefaults.cardColors(containerColor = Color.Transparent),
                shape = RoundedCornerShape(26.dp),
                modifier = Modifier.fillMaxWidth().height(48.dp)
                    .background(Brush.horizontalGradient(listOf(Color(0xFFFF6FA8), Color(0xFF7C4DFF))), RoundedCornerShape(26.dp))
                    .clickable {
                        scope.launch {
                            app.settings.setSelectedCharacterId(selected)
                            app.audio.play(AudioCue.Se("button_tap"))
                            onConfirm()
                        }
                    }
                    .testTag("character_confirm_button"),
            ) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("✨ このキャラで決定 ✨", color = Color.White, fontWeight = FontWeight.Black, fontSize = 15.sp)
                }
            }
        }
        // 拡大モーダル
        modalOpen?.let { (id, variant) ->
            CharacterModal(
                characterId = id,
                variant = variant,
                displayName = characters.firstOrNull { it.id == id }?.displayName,
                onDismiss = { modalOpen = null },
            )
        }
    }
}

@Composable
private fun CharCard(characterId: String, displayName: String, selected: Boolean, onClick: () -> Unit) {
    val transition = rememberInfiniteTransition(label = "cc-$characterId")
    val pulse by transition.animateFloat(
        1f, 1.06f,
        infiniteRepeatable(tween(700, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "cc-pulse",
    )
    val borderColor = characterAccentColor(characterId)
    Card(
        colors = CardDefaults.cardColors(
            containerColor = if (selected) borderColor.copy(alpha = 0.9f) else Color(0x66000000),
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .width(74.dp)
            .height(96.dp)
            .scale(if (selected) pulse else 1f)
            .clickable { onClick() }
            .testTag("character_card_$characterId"),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Box(
                modifier = Modifier.fillMaxWidth().weight(1f)
                    .background(Color(0x33000000), RoundedCornerShape(8.dp)),
            ) {
                CharacterImage(
                    characterId = characterId,
                    variant = CharacterVariant.NORMAL,
                    modifier = Modifier.fillMaxSize(),
                    fallbackLabel = "",
                )
            }
            Text(
                displayName,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                color = if (selected) Color(0xFF1A0F2E) else Color.White,
            )
        }
    }
}

private fun characterAccentColor(id: String): Color = when (id) {
    "hina" -> Color(0xFFFFC0CB)
    "airi" -> Color(0xFF7FFF00)
    "yuki" -> Color(0xFFE0FFFF)
    "mio" -> Color(0xFF8A2BE2)
    "rin" -> Color(0xFFDC143C)
    "apuririri" -> Color(0xFFFF8C42)
    else -> Color(0xFF7C4DFF)
}

private fun characterSkillName(id: String): String = when (id) {
    "hina" -> "ハートエクスプロージョン"
    "airi" -> "リーフストーム"
    "yuki" -> "アイスフリーズ"
    "mio" -> "ムーンライトブレス"
    "rin" -> "ライトニングブレイク"
    "apuririri" -> "ギャルサンシャイン"
    else -> "スペシャル"
}

private fun characterSkillDesc(id: String): String = when (id) {
    "hina" -> "中央エリアと縦 2 列を一気に消去。全体バランス型"
    "airi" -> "GREEN + 偶数行を一掃。緑ぷよが多い時が狙い目"
    "yuki" -> "OJAMA + BLUE を全消し。おじゃまぷよ対策の切り札"
    "mio" -> "PURPLE + RED を全消し。魔法系配色に強い"
    "rin" -> "ランダム 3 列を最上段から一気に消去。運試し"
    "apuririri" -> "YELLOW + 上位 3 行を一掃。派手に決めるギャル型"
    else -> "-"
}
