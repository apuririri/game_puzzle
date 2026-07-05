package com.example.myapp.ui.screen

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.example.myapp.App
import com.example.myapp.data.seed.AssetSeeder
import com.example.myapp.domain.model.CharacterVariant
import com.example.myapp.settings.AppSettings
import com.example.myapp.ui.component.CharacterImage

/**
 * CPU 対戦モード（簡易版: 自フィールド + CPU 表示プレースホルダー）。
 * 設計書: docs/設計/features/CPU対戦モード.md
 */
@Composable
fun CpuBattleScreen(onGameOver: (Long, Int, String) -> Unit) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val settings by app.settings.settings.collectAsState(initial = AppSettings())
    // CPU 相手はプレイヤー選択キャラ以外からランダム 1 名（プレイ開始時に固定）
    val cpuId = remember(settings.selectedCharacterId) {
        val candidates = AssetSeeder.DEFAULT_CHARACTERS
            .map { it.id }
            .filter { it != settings.selectedCharacterId }
        candidates.getOrElse(kotlin.random.Random.nextInt(candidates.size)) { "airi" }
    }
    Box(modifier = Modifier.fillMaxSize().testTag("cpu_battle_root")) {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.fillMaxWidth().padding(8.dp).testTag("cpu_enemy_field")) {
                Text("[CPU フィールド プレースホルダー]", color = MaterialTheme.colorScheme.tertiary)
            }
            Text("OJAMA予告 自:0 / 敵:0",
                modifier = Modifier.padding(horizontal = 8.dp).testTag("cpu_player_ojama"))
            Box(modifier = Modifier.fillMaxWidth().height(140.dp)
                .padding(horizontal = 8.dp).testTag("cpu_enemy_character_image")) {
                CharacterImage(
                    characterId = cpuId,
                    variant = CharacterVariant.ANGER,
                    modifier = Modifier.fillMaxWidth().height(140.dp),
                    fallbackLabel = "[CPU 立ち絵]",
                )
            }
            Text(" ", modifier = Modifier.testTag("cpu_enemy_ojama"))
            Box(modifier = Modifier.fillMaxSize().testTag("cpu_player_field")) {
                EndlessScreen(onGameOver = onGameOver, rootTag = "cpu_player_inner")
            }
        }
    }
}
