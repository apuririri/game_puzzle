package com.example.myapp.ui.screen

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.example.myapp.App
import com.example.myapp.audio.AudioCue
import com.example.myapp.settings.Difficulty
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * 設定画面。設計書: docs/設計/features/設定.md
 */
@Composable
fun SettingsScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val state by app.settings.settings.collectAsState(initial = com.example.myapp.settings.AppSettings())
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState())
            .testTag("settings_root"),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("設定")

        Text("難易度")
        Column(modifier = Modifier.testTag("settings_difficulty_select")) {
            Difficulty.values().forEach { diff ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(
                        selected = state.difficulty == diff,
                        onClick = { scope.launch { app.settings.setDifficulty(diff) } },
                        modifier = Modifier.testTag("settings_difficulty_${diff.name}"),
                    )
                    Text(diff.name)
                }
            }
        }

        Text("BGM 音量: ${(state.bgmVolume * 100).toInt()}%")
        Slider(
            value = state.bgmVolume,
            onValueChange = { v -> scope.launch { app.settings.setBgmVolume(v) } },
            modifier = Modifier.testTag("settings_bgm_volume"),
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("BGM")
            Switch(
                checked = state.bgmEnabled,
                onCheckedChange = { v -> scope.launch { app.settings.setBgmEnabled(v) } },
                modifier = Modifier.testTag("settings_bgm_toggle"),
            )
            Spacer(modifier = Modifier.padding(4.dp))
            Button(
                onClick = { app.audio.playBgm("title") },
                modifier = Modifier.testTag("settings_bgm_preview_button"),
            ) { Text("試聴") }
        }

        Text("SE 音量: ${(state.seVolume * 100).toInt()}%")
        Slider(
            value = state.seVolume,
            onValueChange = { v -> scope.launch { app.settings.setSeVolume(v) } },
            modifier = Modifier.testTag("settings_se_volume"),
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("SE")
            Switch(
                checked = state.seEnabled,
                onCheckedChange = { v -> scope.launch { app.settings.setSeEnabled(v) } },
                modifier = Modifier.testTag("settings_se_toggle"),
            )
            Spacer(modifier = Modifier.padding(4.dp))
            Button(
                onClick = { app.audio.play(AudioCue.Se("pop_big")) },
                modifier = Modifier.testTag("settings_se_preview_button"),
            ) { Text("試聴") }
        }

        Text("ボイス 音量: ${(state.voiceVolume * 100).toInt()}%")
        Slider(
            value = state.voiceVolume,
            onValueChange = { v -> scope.launch { app.settings.setVoiceVolume(v) } },
            modifier = Modifier.testTag("settings_voice_volume"),
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("ボイス")
            Switch(
                checked = state.voiceEnabled,
                onCheckedChange = { v -> scope.launch { app.settings.setVoiceEnabled(v) } },
                modifier = Modifier.testTag("settings_voice_toggle"),
            )
            Spacer(modifier = Modifier.padding(4.dp))
            Button(
                onClick = { app.audio.play(AudioCue.Voice(state.selectedCharacterId, "select_preview")) },
                modifier = Modifier.testTag("settings_voice_preview_button"),
            ) { Text("試聴") }
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("大連鎖クリップ自動保存")
            Switch(
                checked = state.chainClipEnabled,
                onCheckedChange = { v -> scope.launch { app.settings.setChainClipEnabled(v) } },
                modifier = Modifier.testTag("settings_chain_clip_toggle"),
            )
        }

        Button(onClick = onBack, modifier = Modifier.fillMaxWidth().testTag("settings_back_button")) {
            Text("戻る")
        }
    }
}
