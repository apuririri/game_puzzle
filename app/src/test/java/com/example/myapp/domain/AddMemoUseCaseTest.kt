package com.example.myapp.domain

import com.example.myapp.data.repository.MemoRepositoryApi
import com.example.myapp.domain.model.Memo
import com.example.myapp.domain.usecase.AddMemoUseCase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** 単体テストの雛形（JUnit / 画面なし）。Repository は in-memory フェイク。 */
class AddMemoUseCaseTest {

    private class FakeRepo : MemoRepositoryApi {
        val added = mutableListOf<Pair<String, String>>()
        private val flow = MutableStateFlow<List<Memo>>(emptyList())
        override fun observeMemos(): Flow<List<Memo>> = flow
        override suspend fun addMemo(title: String, body: String) {
            added += title to body
        }
    }

    @Test
    fun add_valid_title_succeeds() = runTest {
        val repo = FakeRepo()
        val useCase = AddMemoUseCase(repo)
        val result = useCase("買い物リスト")
        assertTrue(result.isSuccess)
        assertEquals(listOf("買い物リスト" to ""), repo.added)
    }

    @Test
    fun add_blank_title_fails() = runTest {
        val repo = FakeRepo()
        val useCase = AddMemoUseCase(repo)
        val result = useCase("   ")
        assertTrue(result.isFailure)
        assertTrue(repo.added.isEmpty())
    }

    @Test
    fun title_is_trimmed() = runTest {
        val repo = FakeRepo()
        val useCase = AddMemoUseCase(repo)
        useCase("  メモ  ")
        assertEquals("メモ", repo.added.single().first)
    }
}
