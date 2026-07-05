package com.example.myapp.data.repository

import com.example.myapp.data.local.dao.MemoDao
import com.example.myapp.data.local.entity.MemoEntity
import com.example.myapp.domain.model.Memo
import com.example.myapp.util.AppLogger
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/** メモのリポジトリ実装（Room）。domain 層は MemoRepositoryApi 経由で参照する。 */
interface MemoRepositoryApi {
    fun observeMemos(): Flow<List<Memo>>
    suspend fun addMemo(title: String, body: String = "")
}

class MemoRepository(private val dao: MemoDao) : MemoRepositoryApi {
    override fun observeMemos(): Flow<List<Memo>> =
        dao.observeAll().map { list -> list.map { Memo(it.id, it.title, it.body, it.createdAt) } }

    override suspend fun addMemo(title: String, body: String) {
        AppLogger.db("addMemo title=$title")
        dao.insert(MemoEntity(title = title, body = body))
    }
}
