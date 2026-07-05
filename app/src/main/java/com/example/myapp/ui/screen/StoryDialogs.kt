package com.example.myapp.ui.screen

import com.example.myapp.domain.model.CharacterVariant

/**
 * ストーリーモード章別台詞テーブル。6 キャラ × 3 章 × 各 3-5 台詞。
 * 設計書: docs/設計/features/ストーリーモード.md / S1 Q2「1 キャラ 3 章」
 *
 * 章の流れ:
 *   1章 = 出会い（会話中心）
 *   2章 = 特訓（キャラの成長・葛藤）
 *   3章 = 決戦（クライマックス）
 *
 * 章クリア条件（勝利ライン）は StoryScreen 側で章に応じて上げる:
 *   1章: score >= 500
 *   2章: score >= 1500
 *   3章: score >= 3000
 */
internal data class DialogLine(
    val speaker: String,
    val text: String,
    val variant: CharacterVariant,
)

internal object StoryDialogs {
    fun get(characterId: String, chapter: Int): List<DialogLine> {
        val table = TABLE[characterId] ?: TABLE["hina"]!!
        return table.getOrNull(chapter - 1) ?: table[0]
    }

    fun winRequirement(chapter: Int): Long = when (chapter) {
        1 -> 500L
        2 -> 1500L
        3 -> 3000L
        else -> 500L
    }

    fun maxChapters(): Int = 3

    private val TABLE: Map<String, List<List<DialogLine>>> = mapOf(
        "hina" to listOf(
            // 1章: 出会い
            listOf(
                DialogLine("ひな", "こんにちは！　私、ひなだよ♪", CharacterVariant.JOY),
                DialogLine("ひな", "今日から一緒にパズルの世界を旅しよう！", CharacterVariant.NORMAL),
                DialogLine("ひな", "私、パズルはあんまり得意じゃないんだ…", CharacterVariant.SAD),
                DialogLine("ひな", "でも、あなたと一緒なら頑張れる気がする！", CharacterVariant.WINK),
                DialogLine("ひな", "よーし、まずはウォームアップから！", CharacterVariant.CHAIN),
            ),
            // 2章: 特訓
            listOf(
                DialogLine("ひな", "うぅ…連鎖が難しいよぉ…", CharacterVariant.SAD),
                DialogLine("ひな", "でも、諦めない！何度でも挑戦する！", CharacterVariant.ANGER),
                DialogLine("ひな", "きっと私にもできるはず…！", CharacterVariant.THINKING),
                DialogLine("ひな", "見て見て、大連鎖の予感！", CharacterVariant.CHAIN),
            ),
            // 3章: 決戦
            listOf(
                DialogLine("ひな", "ここまで来た…！", CharacterVariant.NORMAL),
                DialogLine("ひな", "みんなの気持ちを背負って戦う！", CharacterVariant.ANGER),
                DialogLine("ひな", "ハートエクスプロージョン、いくよ！", CharacterVariant.BIG_CHAIN),
                DialogLine("ひな", "…そして、伝説へ！", CharacterVariant.VICTORY),
            ),
        ),
        "airi" to listOf(
            listOf(
                DialogLine("あいり", "やあ！　あいりだよ、よろしくねっ！", CharacterVariant.JOY),
                DialogLine("あいり", "パズルは得意なんだ、まかせて！", CharacterVariant.WINK),
                DialogLine("あいり", "リーフストームで一気に片付けちゃう！", CharacterVariant.CHAIN),
                DialogLine("あいり", "さぁ、行くよ、勝負！", CharacterVariant.ANGER),
            ),
            listOf(
                DialogLine("あいり", "ん〜、思ったより難しいな…", CharacterVariant.THINKING),
                DialogLine("あいり", "でも、パパッと解いちゃう！", CharacterVariant.JOY),
                DialogLine("あいり", "リーフストーム、フル発動！", CharacterVariant.CHAIN),
                DialogLine("あいり", "見た？　私の実力！", CharacterVariant.WINK),
            ),
            listOf(
                DialogLine("あいり", "決戦の時、来たね！", CharacterVariant.ANGER),
                DialogLine("あいり", "全部消し飛ばしちゃえ！", CharacterVariant.BIG_CHAIN),
                DialogLine("あいり", "はいっ、勝ちー！！", CharacterVariant.VICTORY),
            ),
        ),
        "yuki" to listOf(
            listOf(
                DialogLine("ゆき", "…どうも、ゆきです。よろしく。", CharacterVariant.NORMAL),
                DialogLine("ゆき", "静かに戦うのが好きなの。", CharacterVariant.THINKING),
                DialogLine("ゆき", "…でも、勝負となれば別。", CharacterVariant.ANGER),
                DialogLine("ゆき", "アイスフリーズ、発動。", CharacterVariant.CHAIN),
            ),
            listOf(
                DialogLine("ゆき", "…集中。", CharacterVariant.THINKING),
                DialogLine("ゆき", "おじゃまぷよは私の敵じゃない。", CharacterVariant.ANGER),
                DialogLine("ゆき", "全部凍らせて…", CharacterVariant.CHAIN),
                DialogLine("ゆき", "…粉々にする。", CharacterVariant.BIG_CHAIN),
            ),
            listOf(
                DialogLine("ゆき", "…最終決戦。", CharacterVariant.NORMAL),
                DialogLine("ゆき", "…冷徹に、勝つ。", CharacterVariant.ANGER),
                DialogLine("ゆき", "アイスフリーズ・オーバードライブ！", CharacterVariant.BIG_CHAIN),
                DialogLine("ゆき", "…勝った。", CharacterVariant.VICTORY),
            ),
        ),
        "mio" to listOf(
            listOf(
                DialogLine("みお", "ふふ…みおよ、よろしく。", CharacterVariant.WINK),
                DialogLine("みお", "魔法と連鎖、どちらも私の得意分野。", CharacterVariant.THINKING),
                DialogLine("みお", "月の光で全てを照らしてあげる。", CharacterVariant.CHAIN),
                DialogLine("みお", "さぁ、始めましょうか。", CharacterVariant.NORMAL),
            ),
            listOf(
                DialogLine("みお", "…この程度で私に勝てると？", CharacterVariant.ANGER),
                DialogLine("みお", "月の魔力を、見せてあげる。", CharacterVariant.CHAIN),
                DialogLine("みお", "ムーンライトブレス、発動！", CharacterVariant.BIG_CHAIN),
                DialogLine("みお", "紫と赤、一気に消えて。", CharacterVariant.WINK),
            ),
            listOf(
                DialogLine("みお", "運命の時、来ましたね。", CharacterVariant.NORMAL),
                DialogLine("みお", "全ての魔力を解き放つ…！", CharacterVariant.BIG_CHAIN),
                DialogLine("みお", "満月の光あれ！", CharacterVariant.VICTORY),
            ),
        ),
        "rin" to listOf(
            listOf(
                DialogLine("りん", "よっ、りんだ！　よろしく頼むぜ！", CharacterVariant.JOY),
                DialogLine("りん", "走るのもパズルも、どっちも得意さ！", CharacterVariant.WINK),
                DialogLine("りん", "行くぞ、一気に決めるぜ！", CharacterVariant.ANGER),
                DialogLine("りん", "ライトニングブレイクだーっ！", CharacterVariant.CHAIN),
            ),
            listOf(
                DialogLine("りん", "うぉぉ、負けねぇ！", CharacterVariant.ANGER),
                DialogLine("りん", "スピードなら誰にも負けない！", CharacterVariant.CHAIN),
                DialogLine("りん", "ライトニング、フルパワー！", CharacterVariant.BIG_CHAIN),
                DialogLine("りん", "どうだ、私の走りは！", CharacterVariant.WINK),
            ),
            listOf(
                DialogLine("りん", "決戦だ、燃えるぜ…！", CharacterVariant.ANGER),
                DialogLine("りん", "全力全開、限界突破！", CharacterVariant.BIG_CHAIN),
                DialogLine("りん", "頂点、取ったぜっ！", CharacterVariant.VICTORY),
            ),
        ),
        "apuririri" to listOf(
            // 1章: 出会い（ギャル女子高生登場）
            listOf(
                DialogLine("あぷりりり", "ハロー☆　あーしのこと、あぷりりりって呼んで♡", CharacterVariant.JOY),
                DialogLine("あぷりりり", "パズルとか超久しぶり〜、まじガチ楽しみっ！", CharacterVariant.WINK),
                DialogLine("あぷりりり", "え、なに？　あーしってギャルに見える？　やば〜、正解！", CharacterVariant.NORMAL),
                DialogLine("あぷりりり", "見た目で舐めんなよ〜、あーし本気出したらガチだから♪", CharacterVariant.THINKING),
                DialogLine("あぷりりり", "よっしゃ、レッツプリズマ〜！", CharacterVariant.CHAIN),
            ),
            // 2章: 特訓
            listOf(
                DialogLine("あぷりりり", "うわマジ？　こんな連鎖ムズくない？", CharacterVariant.SAD),
                DialogLine("あぷりりり", "でもさ〜、あーし諦め悪いの♡", CharacterVariant.ANGER),
                DialogLine("あぷりりり", "ちょ、待って、閃いたかも！　テンアゲ！", CharacterVariant.THINKING),
                DialogLine("あぷりりり", "ギャルサンシャイン、いっちゃえ〜っ！", CharacterVariant.CHAIN),
                DialogLine("あぷりりり", "ほら見た？　あーしのポテンシャルってこんな感じ♪", CharacterVariant.WINK),
            ),
            // 3章: 決戦
            listOf(
                DialogLine("あぷりりり", "きたきたきた〜！　これぞ本番って感じ♡", CharacterVariant.NORMAL),
                DialogLine("あぷりりり", "ここで負けたらあーしのプリじゃないっつーの！", CharacterVariant.ANGER),
                DialogLine("あぷりりり", "ギャルサンシャイン・オーバーロード、ドーン！", CharacterVariant.BIG_CHAIN),
                DialogLine("あぷりりり", "ぶっちぎりで勝ちぃ〜！　あーし最強♡", CharacterVariant.VICTORY),
            ),
        ),
    )
}
