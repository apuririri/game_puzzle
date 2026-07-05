package com.example.myapp.data.repository

import com.example.myapp.data.local.dao.CharacterDao
import com.example.myapp.domain.model.Character
import com.example.myapp.domain.model.CharacterVariant
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map

/**
 * 設計書: docs/設計/features/共通基盤_CharacterRepository.md
 */
class CharacterRepository(private val dao: CharacterDao) {
    fun observe(): Flow<List<Character>> =
        combine(dao.observeAll(), dao.observeAllImages()) { entities, images ->
            entities.map { e ->
                val imgs = images.filter { it.characterId == e.id }
                    .mapNotNull { img -> CharacterVariant.fromString(img.variant)?.let { it to img.assetPath } }
                    .toMap()
                Character(
                    id = e.id,
                    displayName = e.displayName,
                    voiceTone = e.voiceTone,
                    unlocked = e.unlocked,
                    images = imgs,
                )
            }
        }

    fun observeById(id: String): Flow<Character?> = observe().map { list -> list.firstOrNull { it.id == id } }
}
