package com.example.myapp.ui.screen

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
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
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.example.myapp.App
import com.example.myapp.domain.game.GameField
import com.example.myapp.domain.game.GameInput
import com.example.myapp.domain.model.CharacterVariant
import com.example.myapp.ui.component.CharacterImage
import com.example.myapp.ui.component.PuyoOrb
import com.example.myapp.ui.effect.ChainEffectOverlay
import com.example.myapp.ui.viewmodel.PlayViewModel

private fun playFactory(app: App) = viewModelFactory {
    initializer { PlayViewModel(app) }
}

/**
 * エンドレスモード本体。ScoreAttack / Story battle / Cpu battle の自フィールドにも再利用される。
 *
 * 表現要素:
 *  - 動的背景（キャラ立ち絵を alpha 0.14 で重畳、slow pan / breathing 波動 / variant 差替）
 *  - PuyoOrb で装飾ブロック描画（heart/clover/drop/star/moon/bomb ×gradient×shine）
 *  - スキルゲージ + 発動ボタン（キャラ別必殺技）
 *  - 連鎖時オーバーレイ（既存 ChainEffectOverlay）
 *
 * 設計書: docs/設計/features/エンドレスモード.md / 連鎖演出システム.md
 */
@Composable
fun EndlessScreen(
    onGameOver: (Long, Int, String) -> Unit,
    onBackToTitle: () -> Unit = {},
    rootTag: String = "endless_root",
) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val vm: PlayViewModel = viewModel(factory = playFactory(app))
    val state by vm.state.collectAsState()
    val paused by vm.paused.collectAsState()
    val maxChain by vm.maxChain.collectAsState()
    val fallSubRow by vm.fallSubRow.collectAsState()
    val pendingPops by vm.pendingPops.collectAsState()
    val skillGauge by vm.skillGauge.collectAsState()
    val skillActive by vm.skillActive.collectAsState()
    val visualRotation by vm.visualRotation.collectAsState()
    val settings by app.settings.settings.collectAsState(initial = com.example.myapp.settings.AppSettings())
    var showQuitConfirm by remember { mutableStateOf(false) }

    // ハードウェア戻るキー: 実行中なら一時停止、既に一時停止中ならタイトル復帰確認
    androidx.activity.compose.BackHandler {
        if (!paused) vm.togglePause() else showQuitConfirm = true
    }

    LaunchedEffect(Unit) {
        val snap = app.consumePendingResume()
        if (snap != null) {
            try {
                val restored = com.example.myapp.game.save.GameStateCodec.fromSnapshot(snap)
                vm.resumeFrom(restored, snap.maxChain)
            } catch (_: Exception) {
                vm.startNew(PlayViewModel.Mode.ENDLESS)
            }
        } else {
            vm.startNew(PlayViewModel.Mode.ENDLESS)
        }
        app.audio.playBgm("play_normal")
    }

    LaunchedEffect(state.isGameOver) {
        if (state.isGameOver) {
            onGameOver(state.score, maxChain, settings.selectedCharacterId)
        }
    }

    Box(modifier = Modifier.fillMaxSize().background(Brush.verticalGradient(
        listOf(Color(0xFF1A1B2E), Color(0xFF2A1B4E))
    )).testTag(rootTag)) {
        PlayBackground(
            characterId = settings.selectedCharacterId,
            maxChain = maxChain,
            score = state.score,
        )
        Column(
            modifier = Modifier.fillMaxSize().padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            HudRow(
                score = state.score,
                maxChain = maxChain,
                paused = paused,
                onPauseToggle = { vm.togglePause() },
            )
            PlayField(
                state = state,
                fallSubRow = fallSubRow,
                pendingPops = pendingPops,
                visualRotation = visualRotation,
                onTap = { vm.input(GameInput.RotateCw) },
                onSwipeLeft = { vm.input(GameInput.Left) },
                onSwipeRight = { vm.input(GameInput.Right) },
                onSwipeDown = { vm.input(GameInput.HardDrop) },
                modifier = Modifier.fillMaxWidth().weight(1f),
            )
            NextPreview(state = state)
            SkillBar(
                gauge = skillGauge,
                active = skillActive,
                onActivate = { vm.activateSkill(settings.selectedCharacterId) },
                skillName = skillNameFor(settings.selectedCharacterId),
            )
            ControlPad(
                onLeft = { vm.input(GameInput.Left) },
                onRight = { vm.input(GameInput.Right) },
                onRotate = { vm.input(GameInput.RotateCw) },
                onSoft = { vm.input(GameInput.SoftDrop) },
                onHard = { vm.input(GameInput.HardDrop) },
            )
            if (paused) {
                PauseMenu(
                    onResume = { vm.togglePause() },
                    onSave = { vm.saveToSlot(1) },
                    onQuit = { showQuitConfirm = true },
                )
            }
        }
        ChainEffectOverlay(
            events = vm.chainEvents,
            modifier = Modifier.fillMaxSize(),
            characterId = settings.selectedCharacterId,
        )
        if (showQuitConfirm) {
            androidx.compose.material3.AlertDialog(
                onDismissRequest = { showQuitConfirm = false },
                title = { Text("タイトルへ戻りますか？") },
                text = { Text("現在のプレイは失われます（オートセーブは残ります）") },
                confirmButton = {
                    androidx.compose.material3.TextButton(onClick = {
                        showQuitConfirm = false
                        onBackToTitle()
                    }) { Text("タイトルへ", color = Color(0xFFDC143C), fontWeight = FontWeight.Bold) }
                },
                dismissButton = {
                    androidx.compose.material3.TextButton(onClick = { showQuitConfirm = false }) {
                        Text("続ける")
                    }
                },
            )
        }
    }
}

@Composable
private fun PauseMenu(onResume: () -> Unit, onSave: () -> Unit, onQuit: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xEE000000)),
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier.fillMaxWidth().testTag("playfield_pause_menu"),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("⏸ 一時停止中",
                fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF00E5FF),
            )
            androidx.compose.foundation.layout.Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Button(
                    onClick = onResume,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF00E5FF)),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.weight(1f),
                ) { Text("▶ 再開", color = Color(0xFF1A0F2E), fontWeight = FontWeight.Bold) }
                Button(
                    onClick = onSave,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFFC22E)),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.weight(1f),
                ) { Text("💾 セーブ", color = Color(0xFF1A0F2E), fontWeight = FontWeight.Bold) }
                Button(
                    onClick = onQuit,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC143C)),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.weight(1f),
                ) { Text("❌ 中断", color = Color.White, fontWeight = FontWeight.Bold) }
            }
        }
    }
}

@Composable
private fun PlayBackground(characterId: String, maxChain: Int, score: Long) {
    // 連鎖数が伸びるほど variant を変化させて動的感を演出
    val variant = when {
        maxChain >= 5 -> CharacterVariant.BIG_CHAIN
        maxChain >= 3 -> CharacterVariant.CHAIN
        maxChain >= 1 -> CharacterVariant.JOY
        else -> CharacterVariant.NORMAL
    }
    // スロー呼吸アニメ（scale 1.00 ↔ 1.06 / 6 秒周期）
    val transition = rememberInfiniteTransition(label = "bg-breath")
    val breath by transition.animateFloat(
        1.00f, 1.06f,
        infiniteRepeatable(tween(6000, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "bg-breath",
    )
    Box(modifier = Modifier.fillMaxSize().testTag("play_background")) {
        CharacterImage(
            characterId = characterId,
            variant = variant,
            modifier = Modifier.fillMaxSize().scale(breath).alpha(0.16f),
            contentScale = ContentScale.Crop,
            fallbackLabel = "",
        )
    }
}

@Composable
private fun HudRow(score: Long, maxChain: Int, paused: Boolean, onPauseToggle: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0x99000000)),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                Text("SCORE", fontSize = 10.sp, color = Color(0xFF00E5FF))
                Text("$score", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color.White,
                    modifier = Modifier.testTag("playfield_score"))
            }
            Column {
                Text("MAX CHAIN", fontSize = 10.sp, color = Color(0xFFFFE680))
                Text("$maxChain", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = Color(0xFFFFC22E),
                    modifier = Modifier.testTag("playfield_chain_count"))
            }
            Button(
                onClick = onPauseToggle,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF7C4DFF)),
                shape = RoundedCornerShape(10.dp),
                modifier = Modifier.testTag("playfield_pause_button"),
            ) { Text(if (paused) "再開" else "停止", fontSize = 12.sp) }
        }
    }
}

@Composable
private fun PlayField(
    state: com.example.myapp.domain.game.StepResult,
    fallSubRow: Float,
    pendingPops: Set<Pair<Int, Int>>,
    visualRotation: Float,
    onTap: () -> Unit,
    onSwipeLeft: () -> Unit,
    onSwipeRight: () -> Unit,
    onSwipeDown: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    // ドラッグ 1 マス移動の閾値（cellSize の半分相当）
    var accumX by remember { mutableStateOf(0f) }
    var accumY by remember { mutableStateOf(0f) }
    var swipedDown by remember { mutableStateOf(false) }
    BoxWithConstraints(
        modifier = modifier
            .testTag("playfield_grid")
            .background(Color(0x66000000), RoundedCornerShape(16.dp))
            .pointerInput(Unit) {
                // タップ = 回転（ダブルタップ不使用、シングルタップで即時 CW 回転）
                detectTapGestures(onTap = { onTap() })
            }
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { accumX = 0f; accumY = 0f; swipedDown = false },
                    onDragEnd = { accumX = 0f; accumY = 0f; swipedDown = false },
                    onDragCancel = { accumX = 0f; accumY = 0f; swipedDown = false },
                ) { change, dragAmount ->
                    change.consume()
                    accumX += dragAmount.x
                    accumY += dragAmount.y
                    val threshDp = 24.dp  // 短めでレスポンシブに
                    val threshPx = with(density) { threshDp.toPx() }
                    while (accumX >= threshPx) { onSwipeRight(); accumX -= threshPx }
                    while (accumX <= -threshPx) { onSwipeLeft(); accumX += threshPx }
                    // 下方向スワイプは 1 回のドラッグにつき 1 度だけ hard drop
                    if (!swipedDown && accumY >= threshPx * 2) {
                        onSwipeDown()
                        swipedDown = true
                    }
                }
            },
    ) {
        val cellW = maxWidth / GameField.COLS
        val cellH = maxHeight / GameField.ROWS
        val cellSize = if (cellW < cellH) cellW else cellH
        val gridWidthPx = cellSize * GameField.COLS
        val gridHeightPx = cellSize * GameField.ROWS
        val leftPad = (maxWidth - gridWidthPx) / 2
        val topPad = (maxHeight - gridHeightPx) / 2

        // 固定セル（着地済みぷよ）
        for (c in 0 until GameField.COLS) {
            for (r in 0 until GameField.ROWS) {
                val cell = state.field.cell(c, r) ?: continue
                val isPopping = (c to r) in pendingPops
                val scale by animateFloatAsState(
                    targetValue = if (isPopping) 1.6f else 1f,
                    animationSpec = tween(durationMillis = 220),
                    label = "pop-scale-$c-$r",
                )
                val alpha by animateFloatAsState(
                    targetValue = if (isPopping) 0f else 1f,
                    animationSpec = tween(durationMillis = 240),
                    label = "pop-alpha-$c-$r",
                )
                Box(
                    modifier = Modifier
                        .size(cellSize)
                        .offset(x = leftPad + cellSize * c, y = topPad + cellSize * (GameField.ROWS - 1 - r))
                        .padding(1.dp)
                        .scale(scale)
                        .alpha(alpha)
                        .testTag(if (isPopping) "playfield_cell_${c}_${r}_popping" else "playfield_cell_${c}_${r}"),
                ) { PuyoOrb(color = cell.color, modifier = Modifier.fillMaxSize()) }
            }
        }

        // ゴースト（着地予測位置）
        val pair: com.example.myapp.domain.game.Pair2? = state.current
        if (pair != null) {
            var landed: com.example.myapp.domain.game.Pair2 = pair
            while (com.example.myapp.domain.game.ChainEngine.canMove(state.field, landed, 0, -1)) {
                landed = landed.copy(row = landed.row - 1)
            }
            if (landed.row != pair.row) {
                val ghostPivotY = topPad + cellSize * (GameField.ROWS - 1 - landed.row).toFloat()
                val ghostPivotX = leftPad + cellSize * landed.col.toFloat()
                val (gdcx, gdcy) = when (landed.rotation % 360) {
                    0 -> 0f to -1f
                    90 -> 1f to 0f
                    180 -> 0f to 1f
                    else -> -1f to 0f
                }
                Box(
                    modifier = Modifier
                        .size(cellSize)
                        .offset(x = ghostPivotX, y = ghostPivotY)
                        .padding(1.dp)
                        .alpha(0.28f)
                        .testTag("playfield_ghost_pivot"),
                ) { PuyoOrb(color = pair.pivot.color, modifier = Modifier.fillMaxSize()) }
                Box(
                    modifier = Modifier
                        .size(cellSize)
                        .offset(x = ghostPivotX + cellSize * gdcx, y = ghostPivotY + cellSize * gdcy)
                        .padding(1.dp)
                        .alpha(0.28f),
                ) { PuyoOrb(color = pair.child.color, modifier = Modifier.fillMaxSize()) }
            }
        }

        // 落下中ペア
        if (pair != null) {
            val animCol by animateFloatAsState(
                targetValue = pair.col.toFloat(),
                animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessHigh),
                label = "pair-col",
            )
            // 累積回転角（0/90/180/270→360→...）を tween 180ms で補間
            val animRot by animateFloatAsState(
                targetValue = visualRotation,
                animationSpec = tween(durationMillis = 180, easing = androidx.compose.animation.core.FastOutSlowInEasing),
                label = "pair-rot",
            )
            val pivotY = topPad + cellSize * ((GameField.ROWS - 1 - pair.row) + fallSubRow)
            val pivotX = leftPad + cellSize * animCol
            // 連続角度から child 相対位置を算出（rotation=0 で真上、CW に回転）
            //   dx =  sin(θ)   dy = -cos(θ)  （画面座標: 上が -y なので dy に -cos）
            val angleRad = Math.toRadians(animRot.toDouble())
            val dcx = kotlin.math.sin(angleRad).toFloat()
            val dcy = -kotlin.math.cos(angleRad).toFloat()
            Box(
                modifier = Modifier
                    .size(cellSize)
                    .offset(x = pivotX, y = pivotY)
                    .padding(1.dp)
                    .testTag("playfield_current_pair"),
            ) { PuyoOrb(color = pair.pivot.color, modifier = Modifier.fillMaxSize()) }
            Box(
                modifier = Modifier
                    .size(cellSize)
                    .offset(x = pivotX + cellSize * dcx, y = pivotY + cellSize * dcy)
                    .padding(1.dp),
            ) { PuyoOrb(color = pair.child.color, modifier = Modifier.fillMaxSize()) }
        }
    }
}

@Composable
private fun NextPreview(state: com.example.myapp.domain.game.StepResult) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        NextTile("NEXT", state.next.pivot.color, state.next.child.color, testTag = "playfield_next")
        NextTile("NEXT 2", state.next2.pivot.color, state.next2.child.color, testTag = "playfield_next_next")
    }
}

@Composable
private fun NextTile(label: String, top: com.example.myapp.domain.game.CellColor, bottom: com.example.myapp.domain.game.CellColor, testTag: String) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0x99000000)),
        shape = RoundedCornerShape(10.dp),
        modifier = Modifier.testTag(testTag),
    ) {
        Row(modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Text(label, fontSize = 10.sp, color = Color(0xFF00E5FF), modifier = Modifier.padding(end = 6.dp))
            Box(modifier = Modifier.size(22.dp)) { PuyoOrb(color = top, modifier = Modifier.fillMaxSize()) }
            Box(modifier = Modifier.size(22.dp).padding(start = 2.dp)) { PuyoOrb(color = bottom, modifier = Modifier.fillMaxSize()) }
        }
    }
}

@Composable
private fun SkillBar(gauge: Float, active: Boolean, onActivate: () -> Unit, skillName: String) {
    val ready = gauge >= 1f
    val transition = rememberInfiniteTransition(label = "skill-pulse")
    val pulse by transition.animateFloat(
        0.90f, 1.05f,
        infiniteRepeatable(tween(500, easing = LinearEasing), repeatMode = RepeatMode.Reverse),
        label = "skill-pulse",
    )
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0x99000000)),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth().testTag("skill_bar"),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    if (ready) "★必殺技チャージ完了★" else "必殺技: $skillName",
                    fontSize = 11.sp,
                    color = if (ready) Color(0xFFFFD700) else Color.White,
                    fontWeight = if (ready) FontWeight.Bold else FontWeight.Normal,
                )
                LinearProgressIndicator(
                    progress = { gauge.coerceIn(0f, 1f) },
                    color = if (ready) Color(0xFFFFD700) else Color(0xFF00E5FF),
                    trackColor = Color(0xFF333355),
                    modifier = Modifier.fillMaxWidth().height(10.dp).testTag("skill_gauge"),
                )
            }
            Button(
                onClick = onActivate,
                enabled = ready && !active,
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (ready) Color(0xFFFFD700) else Color(0xFFFF6FA8),
                    disabledContainerColor = Color(0x66555577),
                ),
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier.padding(start = 10.dp)
                    .scale(if (ready) pulse else 1f)
                    .testTag("skill_activate_button"),
            ) {
                Text(
                    if (ready) skillName else "発動",
                    fontSize = if (ready) 11.sp else 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (ready) Color(0xFF1A0F2E) else Color.White,
                )
            }
        }
    }
}

@Composable
private fun ControlPad(
    onLeft: () -> Unit, onRight: () -> Unit, onRotate: () -> Unit,
    onSoft: () -> Unit, onHard: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            CtrlBtn("←", onLeft, "playfield_btn_left", Modifier.weight(1f))
            CtrlBtn("→", onRight, "playfield_btn_right", Modifier.weight(1f))
            CtrlBtn("回転", onRotate, "playfield_btn_rotate", Modifier.weight(1f))
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            CtrlBtn("早落", onSoft, "playfield_btn_softdrop", Modifier.weight(1f))
            CtrlBtn("即着", onHard, "playfield_btn_harddrop", Modifier.weight(1f))
        }
    }
}

@Composable
private fun CtrlBtn(label: String, onClick: () -> Unit, testTag: String, modifier: Modifier = Modifier) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF7C4DFF)),
        shape = RoundedCornerShape(14.dp),
        modifier = modifier.height(52.dp).testTag(testTag),
    ) { Text(label, fontWeight = FontWeight.Bold) }
}

private fun skillNameFor(characterId: String): String = when (characterId) {
    "hina" -> "ハートエクスプロージョン"
    "airi" -> "リーフストーム"
    "yuki" -> "アイスフリーズ"
    "mio" -> "ムーンライトブレス"
    "rin" -> "ライトニングブレイク"
    "apuririri" -> "ギャルサンシャイン"
    else -> "スペシャル"
}
