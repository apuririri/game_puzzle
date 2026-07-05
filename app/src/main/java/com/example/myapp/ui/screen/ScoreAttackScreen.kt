package com.example.myapp.ui.screen

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.example.myapp.App
import com.example.myapp.settings.AppSettings
import kotlinx.coroutines.delay

/**
 * スコアアタックモード。エンドレスを内側で再利用しタイマーを上にかぶせる。
 * 設計書: docs/設計/features/スコアアタックモード.md
 */
@Composable
fun ScoreAttackScreen(durationMs: Long = 180_000L, onTimeUp: (Long, Int, String) -> Unit) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val settings by app.settings.settings.collectAsState(initial = AppSettings())
    var remaining by remember { mutableLongStateOf(durationMs) }

    LaunchedEffect(Unit) {
        val start = System.currentTimeMillis()
        while (remaining > 0) {
            delay(500L)
            remaining = (durationMs - (System.currentTimeMillis() - start)).coerceAtLeast(0L)
        }
        // タイマー切れ時は選択中キャラで通知（v0.2 で hina 固定を撤廃）
        onTimeUp(0L, 0, settings.selectedCharacterId.ifBlank { "hina" })
    }

    Box(modifier = Modifier.fillMaxSize().testTag("score_attack_root")) {
        EndlessScreen(onGameOver = onTimeUp, rootTag = "score_attack_root_inner")
        Column(modifier = Modifier.padding(8.dp)) {
            Text("残り: ${remaining / 1000} 秒", modifier = Modifier.testTag("scoreattack_timer_text"))
        }
    }
}
