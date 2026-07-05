package com.example.myapp.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.myapp.data.local.AppDatabase
import com.example.myapp.data.repository.MemoRepository
import com.example.myapp.domain.model.Memo
import com.example.myapp.domain.usecase.AddMemoUseCase
import com.example.myapp.util.AppLogger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class HomeUiState(
    val input: String = "",
    val memos: List<Memo> = emptyList(),
    val error: String? = null
)

/** ホーム画面の ViewModel（StateFlow / 雛形は DI ライブラリ無しの手動組み立て）。 */
class HomeViewModel(application: Application) : AndroidViewModel(application) {

    private val repository = MemoRepository(AppDatabase.getInstance(application).memoDao())
    private val addMemoUseCase = AddMemoUseCase(repository)

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.observeMemos().collect { memos ->
                _uiState.update { it.copy(memos = memos) }
            }
        }
    }

    fun onInputChange(value: String) {
        _uiState.update { it.copy(input = value, error = null) }
    }

    fun addMemo() {
        val title = _uiState.value.input
        viewModelScope.launch {
            addMemoUseCase(title)
                .onSuccess {
                    AppLogger.ui("memo added: $title")
                    _uiState.update { it.copy(input = "", error = null) }
                }
                .onFailure { e ->
                    AppLogger.uiError("addMemo failed", e)
                    _uiState.update { it.copy(error = e.message ?: "追加に失敗しました") }
                }
        }
    }
}
