package com.example.myapp.ui.viewmodel

import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.myapp.App
import com.example.myapp.audio.AudioCue
import com.example.myapp.domain.game.ChainEngine
import com.example.myapp.domain.game.ChainEvent
import com.example.myapp.domain.game.GameField
import com.example.myapp.domain.game.GameInput
import com.example.myapp.domain.game.Pair2
import com.example.myapp.domain.game.StepResult
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * プレイ画面共通の ViewModel。EndlessScreen / ScoreAttackScreen / Story battle で再利用。
 *
 * tick 周期と落下速度を分離して滑らかな落下を実現:
 *   - TICK_MS: 描画 + 入力反映の周期（50ms / 20fps、UI 側はさらに animateFloatAsState で補間）
 *   - FALL_MS_PER_CELL: 1 マス降下にかける時間（500ms）= 10 tick
 *
 * 連鎖は 1 段ずつ ChainEngine.popOneStep で進める:
 *   - 消去対象セルを pendingPops に置く
 *   - POP_ANIM_MS の間 UI でスケール+フェードアニメ
 *   - 完了後に field を確定して次段を判定、間に CHAIN_DELAY_MS の余韻
 *
 * 設計書: docs/設計/features/エンドレスモード.md / 共通基盤_ChainEngine.md / 連鎖演出システム.md
 */
class PlayViewModel(app: App) : AndroidViewModel(app) {

    enum class Mode { ENDLESS, SCORE_ATTACK, CPU_BATTLE, STORY }

    companion object {
        const val TICK_MS = 32L                  // ~30fps の描画粒度
        const val FALL_MS_PER_CELL = 350L        // ぷよぷよ標準（300-400ms/マス）
        private const val POP_ANIM_MS = 320L     // 弾けるパーティクル感
        private const val CHAIN_DELAY_MS = 180L  // 次段までの余韻
    }

    private val _state = MutableStateFlow(ChainEngine.initialState(seed = System.currentTimeMillis()))
    val state: StateFlow<StepResult> = _state.asStateFlow()

    private val _paused = MutableStateFlow(false)
    val paused: StateFlow<Boolean> = _paused.asStateFlow()

    private val _maxChain = MutableStateFlow(0)
    val maxChain: StateFlow<Int> = _maxChain.asStateFlow()

    private val _chainEvents = MutableSharedFlow<ChainEvent>(extraBufferCapacity = 16)
    val chainEvents: SharedFlow<ChainEvent> = _chainEvents.asSharedFlow()

    /** 落下中ペアの「次のセルまでの進捗」0.0..1.0。UI 側で 1 マス分の Y オフセットに乗算する。 */
    private val _fallSubRow = MutableStateFlow(0f)
    val fallSubRow: StateFlow<Float> = _fallSubRow.asStateFlow()

    /** 消去アニメ中のセル座標。UI 側でこのセルに scale+fade を適用。 */
    private val _pendingPops = MutableStateFlow<Set<Pair<Int, Int>>>(emptySet())
    val pendingPops: StateFlow<Set<Pair<Int, Int>>> = _pendingPops.asStateFlow()

    /**
     * 描画用の累積回転角（度）。RotateCw のたびに +90 加算し 360 で mod しない
     * → animateFloatAsState が常に「順方向 (CW)」に補間する。0/90/180/270 → 360 と進み、
     * ペア差替時に 360 の倍数へ丸めることで累積は再ロールしないが Float 精度上ほぼ安全。
     */
    private val _visualRotation = MutableStateFlow(0f)
    val visualRotation: StateFlow<Float> = _visualRotation.asStateFlow()

    /** 連鎖アニメ進行中フラグ。true の間は入力と落下を受け付けない。 */
    private val _isResolving = MutableStateFlow(false)
    val isResolving: StateFlow<Boolean> = _isResolving.asStateFlow()

    /** スキルゲージ 0.0..1.0。消去セルごとに 0.02 増加、満タンで発動可能。 */
    private val _skillGauge = MutableStateFlow(0f)
    val skillGauge: StateFlow<Float> = _skillGauge.asStateFlow()

    /** スキル発動中フラグ。true の間は入力を受け付けず、スキルアニメが走る。 */
    private val _skillActive = MutableStateFlow(false)
    val skillActive: StateFlow<Boolean> = _skillActive.asStateFlow()

    private var tickJob: Job? = null
    private var seedCounter: Long = 0L

    var mode: Mode = Mode.ENDLESS
        private set

    fun startNew(mode: Mode) {
        this.mode = mode
        seedCounter = System.currentTimeMillis()
        _state.value = ChainEngine.initialState(seed = seedCounter)
        _paused.value = false
        _maxChain.value = 0
        _fallSubRow.value = 0f
        _visualRotation.value = 0f
        _pendingPops.value = emptySet()
        _isResolving.value = false
        _skillGauge.value = 0f
        _skillActive.value = false
        startTickLoop()
    }

    fun resumeFrom(initial: StepResult, snapshotMaxChain: Int = 0) {
        seedCounter = System.currentTimeMillis()
        _state.value = initial
        _paused.value = false
        _maxChain.value = snapshotMaxChain
        _fallSubRow.value = 0f
        _visualRotation.value = 0f
        _pendingPops.value = emptySet()
        _isResolving.value = false
        _skillGauge.value = 0f
        _skillActive.value = false
        startTickLoop()
    }

    /**
     * 手動セーブスロットに現在の状態を保存。
     */
    fun saveToSlot(index: Int) {
        val snap = com.example.myapp.game.save.GameStateCodec.toSnapshot(
            _state.value, mode.name, _maxChain.value, 0L,
        )
        viewModelScope.launch {
            try { getApplication<App>().saveLoad.saveSlot(index, snap) } catch (_: Exception) {}
        }
    }

    /**
     * UI から入力（左右移動・回転・ハードドロップ）を受ける。アニメ中は無視。
     */
    fun input(input: GameInput) {
        if (_paused.value || _isResolving.value || _skillActive.value) return
        val cur = _state.value
        val pair = cur.current ?: return
        when (input) {
            GameInput.Left -> if (ChainEngine.canMove(cur.field, pair, -1, 0)) {
                _state.value = cur.copy(current = pair.copy(col = pair.col - 1))
                playSe("move")
            }
            GameInput.Right -> if (ChainEngine.canMove(cur.field, pair, 1, 0)) {
                _state.value = cur.copy(current = pair.copy(col = pair.col + 1))
                playSe("move")
            }
            GameInput.RotateCw -> {
                val rotated = pair.copy(rotation = (pair.rotation + 90) % 360)
                if (ChainEngine.canPlace(cur.field, rotated)) {
                    _state.value = cur.copy(current = rotated)
                    _visualRotation.value = _visualRotation.value + 90f
                    playSe("rotate")
                }
            }
            GameInput.SoftDrop -> {
                // ソフトドロップは fallSubRow を 1.0 に押し上げ、次 tick で 1 マス降下相当
                _fallSubRow.value = 1f
            }
            GameInput.HardDrop -> {
                var p = pair
                while (ChainEngine.canMove(cur.field, p, 0, -1)) {
                    p = p.copy(row = p.row - 1)
                }
                _state.value = cur.copy(current = p)
                _fallSubRow.value = 1f
                playSe("harddrop")
                // 直後の tick で resolveLand が走るので二重実行しない（_isResolving で防衛）
            }
            GameInput.Tick -> { /* 内部 tick からのみ */ }
        }
    }

    fun togglePause() { _paused.value = !_paused.value }

    fun stop() {
        tickJob?.cancel(); tickJob = null
    }

    private fun startTickLoop() {
        tickJob?.cancel()
        tickJob = viewModelScope.launch {
            // Difficulty 別の落下速度スケール（Easy: 遅い / Expert: 速い）
            val diff = getApplication<App>().audio.currentSettings.value.difficulty
            val speedMul = when (diff) {
                com.example.myapp.settings.Difficulty.Easy -> 1.6f
                com.example.myapp.settings.Difficulty.Normal -> 1.0f
                com.example.myapp.settings.Difficulty.Hard -> 0.7f
                com.example.myapp.settings.Difficulty.Expert -> 0.45f
            }
            val fallMs = (FALL_MS_PER_CELL * speedMul).toLong().coerceAtLeast(80L)
            val tickFraction = TICK_MS.toFloat() / fallMs.toFloat()
            while (true) {
                delay(TICK_MS)
                if (_paused.value || _isResolving.value || _skillActive.value || _state.value.isGameOver) {
                    if (_state.value.isGameOver) break
                    continue
                }
                val cur = _state.value
                val pair = cur.current ?: continue
                if (ChainEngine.canMove(cur.field, pair, 0, -1)) {
                    val newSub = _fallSubRow.value + tickFraction
                    if (newSub >= 1f) {
                        _state.value = cur.copy(current = pair.copy(row = pair.row - 1))
                        _fallSubRow.value = 0f
                    } else {
                        _fallSubRow.value = newSub
                    }
                } else {
                    _fallSubRow.value = 0f
                    resolveLand()
                }
            }
        }
    }

    /**
     * 着地→消去→連鎖を 1 段ずつ進める suspend。
     * pendingPops を立ててアニメ時間だけ待ち、field を確定して次段へ。
     */
    private suspend fun resolveLand() {
        _isResolving.value = true
        try {
            val cur = _state.value
            val pair = cur.current ?: return
            // 着地（重力含む）
            var field = ChainEngine.placeAndGravity(cur.field, pair)
            playSe("land")
            _state.value = cur.copy(field = field, current = null)
            // 連鎖を 1 段ずつ
            var level = 1
            var score = cur.score
            var topLevel = 0
            while (true) {
                val (event, newField, scoreDelta) = ChainEngine.popOneStep(field, level)
                if (event == null) break
                // 1) 消去対象セルをアニメ表示
                _pendingPops.value = event.cellsToPop.toSet()
                _chainEvents.tryEmit(event)
                handleChainSideEffects(event)
                // スキルゲージ蓄積: 消去セルで蓄積 + 連鎖 level ボーナス
                _skillGauge.value = (_skillGauge.value +
                    event.cellsToPop.size * 0.020f +
                    event.level * 0.030f).coerceAtMost(1f)
                delay(POP_ANIM_MS)
                // 2) field 確定、pendingPops クリア
                field = newField
                score += scoreDelta
                _pendingPops.value = emptySet()
                _state.value = _state.value.copy(field = field, score = score)
                if (event.level > _maxChain.value) _maxChain.value = event.level
                if (event.level > topLevel) topLevel = event.level
                level += 1
                delay(CHAIN_DELAY_MS)
            }
            // BGM intensify 解除（5+連鎖を経由していた場合）
            if (topLevel >= 5) {
                getApplication<App>().audio.playBgm("play_normal")
            }
            // 新しい current/next を投入
            seedCounter += 1
            val newCurrent = _state.value.next
            val nextPair = _state.value.next2
            val next2Pair = ChainEngine.newPair(seedCounter)
            val isGameOver = !ChainEngine.canPlace(field, newCurrent)
            _state.value = _state.value.copy(
                current = if (isGameOver) null else newCurrent,
                next = nextPair,
                next2 = next2Pair,
                isGameOver = isGameOver,
            )
            // visualRotation を newCurrent.rotation(=0) の 360 倍数に合わせて初期化
            // → 次回 RotateCw で +90 されて 90 → 90 が visualRotation。連続 CW を維持
            _visualRotation.value = 0f
            persistAutoSave()
        } finally {
            _isResolving.value = false
        }
    }

    private fun handleChainSideEffects(ev: ChainEvent) {
        val app = getApplication<App>()
        when {
            ev.level >= 5 -> {
                app.audio.playBgm("play_intense")
                app.audio.play(AudioCue.Se("pop_big"))
                viewModelScope.launch {
                    app.clipRecorder.captureIfBigChain(ev, snapshotBytes = null)
                }
            }
            ev.level >= 3 -> app.audio.play(AudioCue.Se("pop_big"))
            else -> app.audio.play(AudioCue.Se("pop_small"))
        }
        // 連鎖ボイス
        val charId = app.audio.currentSettings.value.selectedCharacterId
        val voiceEvent = when {
            ev.level >= 5 -> "chain_big"
            ev.level >= 2 -> "chain_2"
            else -> "chain_1"
        }
        app.audio.play(AudioCue.Voice(charId, voiceEvent))
    }

    private fun playSe(eventId: String) {
        getApplication<App>().audio.play(AudioCue.Se(eventId))
    }

    private fun persistAutoSave() {
        val snap = com.example.myapp.game.save.GameStateCodec.toSnapshot(
            _state.value, mode.name, _maxChain.value, 0L,
        )
        viewModelScope.launch {
            try { getApplication<App>().saveLoad.autoSave(snap) } catch (_: Exception) {}
        }
    }

    /**
     * キャラ別必殺技を発動。ゲージ満タンかつ非発動状態のときのみ実行。
     *  - hina: ハートエクスプロージョン: 中央 3x3 領域 + 中央列を全消去
     *  - airi: リーフストーム: 上から偶数行の 3 行を全消去（緑優遇）
     *  - yuki: アイスフリーズ: 全おじゃまを消去 + 全 BLUE を消去
     *  - mio:  ムーンライトブレス: フィールド上の PURPLE と RED を消去
     *  - rin:  ライトニングブレイク: ランダム列 3 本を最上段から全消去
     * 副作用: ゲージ 0 に戻す / SE 発火 / bonus score / ChainEvent 発火（演出）
     */
    fun activateSkill(characterId: String) {
        if (_skillActive.value || _skillGauge.value < 1f || _isResolving.value) return
        // フィールドに何も無ければ発動しない（ゲージ温存）
        val fieldEmpty = (0 until GameField.COLS).all { c ->
            (0 until GameField.ROWS).all { r -> _state.value.field.cell(c, r) == null }
        }
        if (fieldEmpty) return

        viewModelScope.launch {
            _skillActive.value = true
            try {
                val app = getApplication<App>()
                app.audio.play(AudioCue.Se("pop_big"))
                // 発動時はスキル専用ボイス（無ければ chain_big に fallback）
                app.audio.playVoice(characterId, "skill")

                val cur = _state.value
                val cellsToClear: Set<Pair<Int, Int>> = computeSkillCells(characterId, cur.field)
                if (cellsToClear.isEmpty()) return@launch  // 対象なし → 早期 return（ゲージ温存）

                // 演出（弾けるアニメ）
                _pendingPops.value = cellsToClear
                _chainEvents.tryEmit(
                    ChainEvent(
                        level = 6,  // ULTRA tier 相当
                        poppedCount = cellsToClear.size,
                        colors = cellsToClear.mapNotNull { (c, r) -> cur.field.cell(c, r)?.color }.distinct(),
                        cellsToPop = cellsToClear.toList(),
                    )
                )
                delay(POP_ANIM_MS + 200L)

                // 実消去 + 重力
                var f = cur.field
                for ((c, r) in cellsToClear) f = f.set(c, r, null)
                f = ChainEngine.applyGravity(f)
                val bonus = cellsToClear.size * 100L
                _pendingPops.value = emptySet()
                _state.value = cur.copy(field = f, score = cur.score + bonus)
                delay(200L)

                // 発動後に自然連鎖が発生するかチェック（1 段だけ）
                val (chainEv, chainField, chainDelta) = ChainEngine.popOneStep(f, 1)
                if (chainEv != null) {
                    _pendingPops.value = chainEv.cellsToPop.toSet()
                    _chainEvents.tryEmit(chainEv)
                    delay(POP_ANIM_MS)
                    _pendingPops.value = emptySet()
                    _state.value = _state.value.copy(field = chainField, score = _state.value.score + chainDelta)
                    if (chainEv.level > _maxChain.value) _maxChain.value = chainEv.level
                }
                persistAutoSave()
            } finally {
                _skillActive.value = false
                _skillGauge.value = 0f  // 例外時でも確実にリセット
            }
        }
    }

    /** キャラ別のスキル対象セル座標セットを計算。 */
    private fun computeSkillCells(characterId: String, field: com.example.myapp.domain.game.GameField): Set<Pair<Int, Int>> {
        val cells = mutableSetOf<Pair<Int, Int>>()
        when (characterId) {
            "hina" -> {
                // 中央 3x3 + 中央 2 列（col 2,3）全部
                for (c in 1..4) for (r in 4..8) if (field.cell(c, r) != null) cells.add(c to r)
                for (c in 2..3) for (r in 0 until com.example.myapp.domain.game.GameField.ROWS) if (field.cell(c, r) != null) cells.add(c to r)
            }
            "airi" -> {
                // GREEN 全消し + 偶数行全部
                for (c in 0 until com.example.myapp.domain.game.GameField.COLS) {
                    for (r in 0 until com.example.myapp.domain.game.GameField.ROWS) {
                        val cell = field.cell(c, r) ?: continue
                        if (cell.color == com.example.myapp.domain.game.CellColor.GREEN || r % 2 == 0) {
                            cells.add(c to r)
                        }
                    }
                }
            }
            "yuki" -> {
                // OJAMA 全消し + BLUE 全消し
                for (c in 0 until com.example.myapp.domain.game.GameField.COLS) {
                    for (r in 0 until com.example.myapp.domain.game.GameField.ROWS) {
                        val col = field.cell(c, r)?.color ?: continue
                        if (col == com.example.myapp.domain.game.CellColor.OJAMA ||
                            col == com.example.myapp.domain.game.CellColor.BLUE
                        ) cells.add(c to r)
                    }
                }
            }
            "mio" -> {
                // PURPLE + RED 全消し
                for (c in 0 until com.example.myapp.domain.game.GameField.COLS) {
                    for (r in 0 until com.example.myapp.domain.game.GameField.ROWS) {
                        val col = field.cell(c, r)?.color ?: continue
                        if (col == com.example.myapp.domain.game.CellColor.PURPLE ||
                            col == com.example.myapp.domain.game.CellColor.RED
                        ) cells.add(c to r)
                    }
                }
            }
            "rin" -> {
                // ランダム列 3 本を全消し
                val rnd = java.util.Random(_state.value.score)
                val chosen = mutableSetOf<Int>()
                while (chosen.size < 3) chosen.add(rnd.nextInt(com.example.myapp.domain.game.GameField.COLS))
                for (c in chosen) {
                    for (r in 0 until com.example.myapp.domain.game.GameField.ROWS) {
                        if (field.cell(c, r) != null) cells.add(c to r)
                    }
                }
            }
            "apuririri" -> {
                // YELLOW 全消し + 上位 3 行（0..2）全消し。派手にサンシャイン
                for (c in 0 until com.example.myapp.domain.game.GameField.COLS) {
                    for (r in 0 until com.example.myapp.domain.game.GameField.ROWS) {
                        val col = field.cell(c, r)?.color ?: continue
                        if (col == com.example.myapp.domain.game.CellColor.YELLOW || r <= 2) {
                            cells.add(c to r)
                        }
                    }
                }
            }
            else -> {
                // fallback: 中央列
                for (r in 0 until com.example.myapp.domain.game.GameField.ROWS) {
                    if (field.cell(2, r) != null) cells.add(2 to r)
                    if (field.cell(3, r) != null) cells.add(3 to r)
                }
            }
        }
        return cells
    }

    override fun onCleared() {
        super.onCleared()
        tickJob?.cancel()
    }
}
