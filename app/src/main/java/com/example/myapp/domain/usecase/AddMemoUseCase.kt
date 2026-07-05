package com.example.myapp.domain.usecase

import com.example.myapp.data.repository.MemoRepositoryApi

/** メモ追加ユースケース。空タイトルは拒否する（単体テスト対象）。 */
class AddMemoUseCase(private val repository: MemoRepositoryApi) {
    suspend operator fun invoke(title: String, body: String = ""): Result<Unit> {
        val trimmed = title.trim()
        if (trimmed.isEmpty()) {
            return Result.failure(IllegalArgumentException("タイトルを入力してください"))
        }
        repository.addMemo(trimmed, body)
        return Result.success(Unit)
    }
}
