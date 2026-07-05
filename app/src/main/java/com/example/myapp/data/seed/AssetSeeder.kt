package com.example.myapp.data.seed

import com.example.myapp.data.local.dao.CharacterDao
import com.example.myapp.data.local.entity.CharacterEntity
import com.example.myapp.data.local.entity.CharacterImageEntity
import com.example.myapp.domain.model.CharacterVariant

/**
 * 初回起動時のキャラマスタ・立ち絵バリエーション登録（6 体 × 10 variant）。
 * 設計書: docs/設計/features/共通基盤_AssetSeeder.md
 *
 * プレースホルダー画像（単色＋ID 文字）の生成はビルド時 Gradle タスク、
 * または初回起動時の res/raw fallback に委譲する（本クラスは DB シードのみ責任）。
 *
 * 追加キャラは差分 upsert で対応（既存 DB でも新キャラが自動追加される）。
 */
class AssetSeeder(private val dao: CharacterDao) {

    data class Bootstrap(val id: String, val displayName: String, val voiceTone: String)

    companion object {
        val DEFAULT_CHARACTERS: List<Bootstrap> = listOf(
            Bootstrap("hina", "ひな", "spk_01"),
            Bootstrap("airi", "あいり", "spk_02"),
            Bootstrap("yuki", "ゆき", "spk_03"),
            Bootstrap("mio", "みお", "spk_04"),
            Bootstrap("rin", "りん", "spk_05"),
            Bootstrap("apuririri", "あぷりりり", "spk_06"),
        )
    }

    suspend fun seedIfEmpty() {
        // 差分 upsert: DAO は OnConflictStrategy.IGNORE のため既存行はそのまま、
        // DEFAULT_CHARACTERS に新規追加されたキャラだけが挿入される。
        val chars = DEFAULT_CHARACTERS.map {
            CharacterEntity(id = it.id, displayName = it.displayName, voiceTone = it.voiceTone, unlocked = true)
        }
        dao.insertAll(chars)
        val images = DEFAULT_CHARACTERS.flatMap { c ->
            CharacterVariant.values().map { v ->
                CharacterImageEntity(
                    id = "${c.id}_${v.asAssetSuffix()}",
                    characterId = c.id,
                    variant = v.asAssetSuffix(),
                    assetPath = "image/character/${c.id}/${v.asAssetSuffix()}.webp",
                )
            }
        }
        dao.insertAllImages(images)
    }
}
