package com.example.myapp.util

import com.example.myapp.data.seed.AssetSeeder

/**
 * キャラ ID → 表示名（日本語）を DEFAULT_CHARACTERS から解決する。
 * Repository を読めない Composable（Result / Ranking の Nav 引数経由 characterId）向け。
 * 未定義 ID の場合は ID をそのまま返す（プレースホルダ）。
 */
object CharacterDisplay {
    fun displayName(characterId: String): String =
        AssetSeeder.DEFAULT_CHARACTERS.firstOrNull { it.id == characterId }?.displayName
            ?: characterId
}
