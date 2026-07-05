package com.example.myapp.domain.model

/**
 * キャラクター（6 体: hina/airi/yuki/mio/rin/apuririri）。
 * 設計書: docs/設計/features/共通基盤_CharacterRepository.md
 */
enum class CharacterVariant {
    NORMAL, JOY, ANGER, SAD, CHAIN, BIG_CHAIN, LOSE, WINK, THINKING, VICTORY;

    fun asAssetSuffix(): String = when (this) {
        NORMAL -> "normal"
        JOY -> "joy"
        ANGER -> "anger"
        SAD -> "sad"
        CHAIN -> "chain"
        BIG_CHAIN -> "bigChain"
        LOSE -> "lose"
        WINK -> "wink"
        THINKING -> "thinking"
        VICTORY -> "victory"
    }

    companion object {
        fun fromString(s: String): CharacterVariant? = values().firstOrNull { it.asAssetSuffix() == s }
    }
}

data class Character(
    val id: String,
    val displayName: String,
    val voiceTone: String,
    val unlocked: Boolean = true,
    val images: Map<CharacterVariant, String> = emptyMap(),
)
