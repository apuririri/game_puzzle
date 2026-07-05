package com.example.myapp.ui.component

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapp.domain.model.CharacterVariant

/**
 * キャラクター立ち絵のモーダル拡大表示。市販ソーシャルゲーム（プリコネ・原神）参照:
 *   - 全画面暗背景（80% 黒 + gradient）で世界観維持
 *   - キャラ立ち絵を最大表示（padding 16dp のみ）
 *   - 右上に閉じる × ボタン + 下部にキャラ名表示
 *   - 背景タップ or × ボタンで閉じる
 *   - AnimatedVisibility で開閉時 fade + scale アニメ
 *
 * 使い方:
 *   var modal: Pair<String, CharacterVariant>? by remember { mutableStateOf(null) }
 *   modal?.let { CharacterModal(it.first, it.second, onDismiss = { modal = null }) }
 */
@Composable
fun CharacterModal(
    characterId: String,
    variant: CharacterVariant,
    displayName: String? = null,
    onDismiss: () -> Unit,
) {
    AnimatedVisibility(
        visible = true,
        enter = fadeIn() + scaleIn(initialScale = 0.85f),
        exit = fadeOut() + scaleOut(),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.radialGradient(
                    listOf(Color(0xEE1A0F2E), Color(0xF8000000)),
                    radius = 1500f,
                ))
                .clickable(indication = null, interactionSource = remember()) { onDismiss() }
                .padding(16.dp),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // × 閉じる（右上）
                Box(
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .background(Color(0xCC000000), CircleShape)
                            .clickable { onDismiss() }
                            .align(Alignment.CenterEnd),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("✕",
                            fontSize = 22.sp, color = Color.White, fontWeight = FontWeight.Black,
                        )
                    }
                }
                // 立ち絵（最大表示）
                Box(
                    modifier = Modifier.fillMaxWidth().weight(1f).padding(vertical = 8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CharacterImage(
                        characterId = characterId,
                        variant = variant,
                        modifier = Modifier.fillMaxSize(),
                        fallbackLabel = displayName ?: characterId,
                    )
                }
                // 名前 + variant ラベル（下部）
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 24.dp)
                        .background(Color(0xAA000000), RoundedCornerShape(20.dp))
                        .padding(vertical = 12.dp),
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(displayName ?: characterId,
                            fontSize = 22.sp, fontWeight = FontWeight.Black,
                            color = Color(0xFFFFC22E),
                        )
                        Text(variant.asAssetSuffix(),
                            fontSize = 11.sp, color = Color(0xFF00E5FF),
                        )
                        Text("画面外をタップして閉じる",
                            fontSize = 10.sp, color = Color(0xFFB0B0C0),
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────
// remember helper for InteractionSource（clickable indication = null 用）
@Composable
private fun remember(): androidx.compose.foundation.interaction.MutableInteractionSource =
    androidx.compose.runtime.remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
