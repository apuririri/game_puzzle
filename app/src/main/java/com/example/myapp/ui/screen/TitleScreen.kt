package com.example.myapp.ui.screen

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.myapp.App
import com.example.myapp.audio.AudioCue
import com.example.myapp.domain.model.CharacterVariant
import com.example.myapp.ui.component.CharacterImage

/**
 * タイトル / メインメニュー。設計書: docs/設計/features/タイトル_メインメニュー.md
 *
 * 演出:
 *  - 選択キャラを画面全体の背景として大きく配置（scale で緩やかにパン）
 *  - 上に半透明グラデーションを重ねて可読性を確保
 *  - タイトル文字はグロー付き + アイドル pulse
 *  - メニューボタンは rounded + gradient
 */
@Composable
fun TitleScreen(
    onStart: () -> Unit,
    onCharacterSelect: () -> Unit,
    onRanking: () -> Unit,
    onTutorial: () -> Unit,
    onSettings: () -> Unit,
    onResume: () -> Unit = {},
) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val settings by app.settings.settings.collectAsState(initial = com.example.myapp.settings.AppSettings())
    val char by remember(settings.selectedCharacterId) {
        app.characterRepo.observeById(settings.selectedCharacterId)
    }.collectAsState(initial = null)
    // 「つづきから」表示判定: autoSave が存在するか非同期チェック
    var hasAutoSave by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        hasAutoSave = try { app.saveLoad.loadAuto() != null } catch (_: Exception) { false }
    }
    // 戻るキー: アプリ終了確認
    var showExitConfirm by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler { showExitConfirm = true }

    LaunchedEffect(Unit) { app.audio.play(AudioCue.Bgm("title")) }
    val scope = rememberCoroutineScope()

    // 背景 pan + pulse
    val infinite = rememberInfiniteTransition(label = "title-anim")
    val panScale by infinite.animateFloat(
        1.05f, 1.15f,
        infiniteRepeatable(tween(9000, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "pan",
    )
    val titlePulse by infinite.animateFloat(
        1.0f, 1.06f,
        infiniteRepeatable(tween(1400, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "title-pulse",
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF1A0F2E), Color(0xFF3A1B5E), Color(0xFF1A0F2E))))
            .testTag("title_root"),
    ) {
        // 背景キャラ立ち絵（10 秒ごとに variant ローテーションで飽きさせない）
        val variants = listOf(
            CharacterVariant.NORMAL, CharacterVariant.WINK,
            CharacterVariant.JOY, CharacterVariant.THINKING,
        )
        val idxState = infinite.animateFloat(
            0f, variants.size.toFloat(),
            infiniteRepeatable(tween(40_000, easing = LinearEasing), repeatMode = RepeatMode.Restart),
            label = "variant-rotate",
        )
        val currentVariant = variants[(idxState.value.toInt() % variants.size).coerceAtLeast(0)]
        CharacterImage(
            characterId = settings.selectedCharacterId,
            variant = currentVariant,
            modifier = Modifier.fillMaxSize().scale(panScale).alpha(0.5f).testTag("title_character_preview"),
            contentScale = ContentScale.Crop,
            fallbackLabel = "",
        )
        // 上下グラデーションで文字読みやすく
        Box(
            modifier = Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    listOf(
                        Color(0xCC1A0F2E), Color(0x661A0F2E), Color(0x881A0F2E), Color(0xEE1A0F2E),
                    )
                )
            )
        )

        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 28.dp, vertical = 40.dp),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                // タイトル: 影付き + pulse
                Box {
                    Text(
                        text = "プリズマ☆リンク",
                        fontSize = 44.sp,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFFFF3366),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().scale(titlePulse * 1.02f).alpha(0.5f)
                            .padding(start = 3.dp, top = 3.dp),
                    )
                    Text(
                        text = "プリズマ☆リンク",
                        fontSize = 44.sp,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFFFFB3D9),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().scale(titlePulse).testTag("title_logo"),
                    )
                }
                Text(
                    text = "Prisma Link ― 美少女連鎖パズル",
                    fontSize = 12.sp,
                    color = Color(0xFF00E5FF),
                    modifier = Modifier.padding(top = 4.dp),
                )
                if (char != null) {
                    Text(
                        text = "選択中: ${char!!.displayName}",
                        fontSize = 14.sp,
                        color = Color(0xFFFFE680),
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
            }

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (hasAutoSave) {
                    MenuBtn(
                        label = "▶ つづきから",
                        tag = "title_resume_button",
                        gradient = listOf(Color(0xFF00E5FF), Color(0xFF7C4DFF)),
                        onClick = {
                            app.audio.play(AudioCue.Se("button_tap"))
                            // autoSave をロード → pendingResume に格納 → プレイ画面へ
                            scope.launch {
                                try {
                                    val snap = app.saveLoad.loadAuto()
                                    if (snap != null) {
                                        app.setPendingResume(snap)
                                        onResume()
                                    }
                                } catch (_: Exception) { /* 黙殺 */ }
                            }
                        },
                    )
                }
                MenuBtn(
                    label = "はじめる",
                    tag = "title_start_button",
                    gradient = listOf(Color(0xFFFF6FA8), Color(0xFF7C4DFF)),
                    onClick = { app.audio.play(AudioCue.Se("button_tap")); onStart() },
                )
                MenuBtn(
                    label = "キャラクター選択",
                    tag = "title_character_select_button",
                    gradient = listOf(Color(0xFF7C4DFF), Color(0xFF00E5FF)),
                    onClick = { app.audio.play(AudioCue.Se("button_tap")); onCharacterSelect() },
                )
                MenuBtn(
                    label = "ランキング",
                    tag = "title_ranking_button",
                    gradient = listOf(Color(0xFFFFC22E), Color(0xFFFF6FA8)),
                    onClick = { app.audio.play(AudioCue.Se("button_tap")); onRanking() },
                )
                MenuBtn(
                    label = "チュートリアル",
                    tag = "title_tutorial_button",
                    gradient = listOf(Color(0xFF00E5FF), Color(0xFF7C4DFF)),
                    onClick = { app.audio.play(AudioCue.Se("button_tap")); onTutorial() },
                )
                MenuBtn(
                    label = "設定",
                    tag = "title_settings_button",
                    gradient = listOf(Color(0xFF9B47DB), Color(0xFF561B85)),
                    onClick = { app.audio.play(AudioCue.Se("button_tap")); onSettings() },
                )
            }
        }
        if (showExitConfirm) {
            androidx.compose.material3.AlertDialog(
                onDismissRequest = { showExitConfirm = false },
                title = { Text("アプリを終了しますか？") },
                text = { Text("いつでも「つづきから」で再開できます。") },
                confirmButton = {
                    androidx.compose.material3.TextButton(onClick = {
                        (ctx as? android.app.Activity)?.finish()
                    }) { Text("終了する", color = Color(0xFFDC143C), fontWeight = FontWeight.Bold) }
                },
                dismissButton = {
                    androidx.compose.material3.TextButton(onClick = { showExitConfirm = false }) {
                        Text("キャンセル")
                    }
                },
            )
        }
    }
}

@Composable
private fun MenuBtn(label: String, tag: String, gradient: List<Color>, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp)
            .background(Brush.horizontalGradient(gradient), RoundedCornerShape(30.dp))
            .testTag(tag),
    ) {
        Button(
            onClick = onClick,
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            shape = RoundedCornerShape(30.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            Text(label, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        }
    }
}
