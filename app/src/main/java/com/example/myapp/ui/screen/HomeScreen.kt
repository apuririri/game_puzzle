package com.example.myapp.ui.screen

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.myapp.ui.viewmodel.HomeViewModel

/**
 * ホーム画面（雛形サンプル: メモの追加・一覧）。
 * testTag 規約（<画面>_<要素>_<種別>）: home_root / home_memo_input / home_add_button / home_memo_list
 * 一覧・testTag は docs/設計/screen_flow.md に同期すること。
 */
@Composable
fun HomeScreen(viewModel: HomeViewModel = viewModel<HomeViewModel>()) {
    val state by viewModel.uiState.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .testTag("home_root"),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(text = "MyApp（AutoDev 雛形）", style = MaterialTheme.typography.titleLarge)

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = state.input,
                onValueChange = viewModel::onInputChange,
                label = { Text("メモ") },
                modifier = Modifier
                    .weight(1f)
                    .testTag("home_memo_input")
            )
            Button(
                onClick = viewModel::addMemo,
                modifier = Modifier.testTag("home_add_button")
            ) {
                Text("追加")
            }
        }

        state.error?.let { err ->
            Text(
                text = err,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.testTag("home_error_text")
            )
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .testTag("home_memo_list"),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(state.memos, key = { it.id }) { memo ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = memo.title,
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }
        }
    }
}
