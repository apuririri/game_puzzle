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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.launch

/**
 * セーブ / ロード スロット画面。設計書: docs/設計/features/セーブ_ロード.md
 *
 * デザイン: スロットカードは mode/score/日時をアイコン付きで表示、
 * 削除は明るい赤ボタン。空スロットは絵文字 + 案内。
 */
@Composable
fun SaveSlotScreen(onBack: () -> Unit, onLoad: (String) -> Unit = {}) {
    val ctx = LocalContext.current
    val app = ctx.applicationContext as App
    val scope = rememberCoroutineScope()
    val slots by app.saveLoad.observeSlots().collectAsState(initial = emptyList())
    androidx.activity.compose.BackHandler { onBack() }

    Box(
        modifier = Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF1A0F2E), Color(0xFF2A1B4E), Color(0xFF1A0F2E))))
            .testTag("save_slot_root"),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("💾 セーブスロット",
                fontSize = 24.sp, fontWeight = FontWeight.Black, color = Color.White,
            )
            if (slots.isEmpty()) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0x66000000)),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth().padding(top = 24.dp),
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text("💾", fontSize = 60.sp)
                        Text("セーブデータがまだありません",
                            fontSize = 16.sp, color = Color.White,
                            fontWeight = FontWeight.Bold,
                        )
                        Text("プレイ中に一時停止からセーブしてね",
                            fontSize = 11.sp, color = Color(0xFFB0B0C0),
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().weight(1f).testTag("save_slot_list"),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(slots, key = { it.slotIndex }) { slot ->
                        val date = SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.getDefault()).format(Date(slot.savedAt))
                        SlotCard(
                            index = slot.slotIndex,
                            mode = slot.mode,
                            score = slot.score,
                            date = date,
                            onLoad = { onLoad(slot.mode) },
                            onDelete = { scope.launch { app.saveLoad.deleteSlot(slot.slotIndex) } },
                        )
                    }
                }
            }
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0xAA000000)),
                shape = RoundedCornerShape(24.dp),
                modifier = Modifier.fillMaxWidth().height(48.dp).clickable { onBack() }.testTag("save_slot_back_button"),
            ) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("← 戻る", fontSize = 14.sp, color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

@Composable
private fun SlotCard(index: Int, mode: String, score: Long, date: String,
                     onLoad: () -> Unit, onDelete: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0x66000000)),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth().testTag("save_slot_$index"),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Column {
                Text("Slot #$index",
                    fontSize = 11.sp, color = Color(0xFF00E5FF), fontWeight = FontWeight.Bold,
                )
                Text("Score: $score",
                    fontSize = 20.sp, fontWeight = FontWeight.Black, color = Color.White,
                )
                Text("$mode / $date",
                    fontSize = 10.sp, color = Color(0xFFB0B0C0),
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFF00E5FF)),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.weight(1f).height(36.dp).clickable { onLoad() }
                        .testTag("save_slot_load_button"),
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("▶ 読み込み", fontSize = 12.sp, color = Color(0xFF1A0F2E), fontWeight = FontWeight.Bold)
                    }
                }
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFDC143C)),
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.weight(1f).height(36.dp).clickable { onDelete() }
                        .testTag("save_slot_delete_button"),
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("🗑 削除", fontSize = 12.sp, color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
