package com.example.myapp.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.navigation.NavType
import kotlinx.coroutines.launch
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.myapp.ui.screen.CharacterSelectScreen
import com.example.myapp.ui.screen.CpuBattleScreen
import com.example.myapp.ui.screen.EndlessScreen
import com.example.myapp.ui.screen.ModeSelectScreen
import com.example.myapp.ui.screen.RankingScreen
import com.example.myapp.ui.screen.ResultScreen
import com.example.myapp.ui.screen.SaveSlotScreen
import com.example.myapp.ui.screen.ScoreAttackScreen
import com.example.myapp.ui.screen.SettingsScreen
import com.example.myapp.ui.screen.StoryScreen
import com.example.myapp.ui.screen.TitleScreen
import com.example.myapp.ui.screen.TutorialScreen

/** 画面ルート定義。設計書: docs/設計/全体設計書.md §3 */
object Routes {
    const val TITLE = "title"
    const val TUTORIAL = "tutorial"
    const val CHARACTER_SELECT = "character_select"
    const val MODE_SELECT = "mode_select"
    const val PLAY_ENDLESS = "play/endless"
    const val PLAY_SCORE_ATTACK = "play/score_attack"
    const val PLAY_STORY = "play/story?characterId={characterId}&chapter={chapter}"
    const val PLAY_CPU = "play/cpu"
    const val RANKING = "ranking?mode={mode}"
    const val SAVE_SLOTS = "save_slots"
    const val SETTINGS = "settings"
    const val RESULT = "result?mode={mode}&score={score}&maxChain={maxChain}&characterId={characterId}"
}

@Composable
fun AppNavHost() {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = Routes.TITLE) {

        composable(Routes.TITLE) {
            TitleScreen(
                onStart = { nav.navigate(Routes.MODE_SELECT) },
                onCharacterSelect = { nav.navigate(Routes.CHARACTER_SELECT) },
                onRanking = { nav.navigate("ranking?mode=endless") },
                onTutorial = { nav.navigate(Routes.TUTORIAL) },
                onSettings = { nav.navigate(Routes.SETTINGS) },
                onResume = { nav.navigate(Routes.PLAY_ENDLESS) },
            )
        }
        composable(Routes.TUTORIAL) {
            TutorialScreen(onDone = { nav.popBackStack() })
        }
        composable(Routes.CHARACTER_SELECT) {
            CharacterSelectScreen(onConfirm = { nav.popBackStack() })
        }
        composable(Routes.MODE_SELECT) {
            val ctx = androidx.compose.ui.platform.LocalContext.current
            val app = ctx.applicationContext as com.example.myapp.App
            val settings by app.settings.settings.collectAsState(
                initial = com.example.myapp.settings.AppSettings()
            )
            ModeSelectScreen(
                onEndless = { nav.navigate(Routes.PLAY_ENDLESS) },
                onScoreAttack = { nav.navigate(Routes.PLAY_SCORE_ATTACK) },
                onStory = {
                    // 選択中キャラのストーリーを再生（v0.2 で hina 固定を撤廃）
                    val cid = settings.selectedCharacterId.ifBlank { "hina" }
                    nav.navigate("play/story?characterId=$cid&chapter=1")
                },
                onCpu = { nav.navigate(Routes.PLAY_CPU) },
                onBack = { nav.popBackStack() },
            )
        }
        composable(Routes.PLAY_ENDLESS) {
            EndlessScreen(
                onGameOver = { score, maxChain, char ->
                    nav.navigate("result?mode=endless&score=$score&maxChain=$maxChain&characterId=$char") {
                        popUpTo(Routes.TITLE) { inclusive = false }
                    }
                },
                onBackToTitle = { nav.popBackStack(Routes.TITLE, inclusive = false) },
            )
        }
        composable(Routes.PLAY_SCORE_ATTACK) {
            ScoreAttackScreen(onTimeUp = { score, maxChain, char ->
                nav.navigate("result?mode=scoreAttack&score=$score&maxChain=$maxChain&characterId=$char") {
                    popUpTo(Routes.TITLE) { inclusive = false }
                }
            })
        }
        composable(
            route = Routes.PLAY_STORY,
            arguments = listOf(
                navArgument("characterId") { type = NavType.StringType; defaultValue = "hina" },
                navArgument("chapter") { type = NavType.IntType; defaultValue = 1 },
            )
        ) { entry ->
            val cid = entry.arguments?.getString("characterId") ?: "hina"
            val ch = entry.arguments?.getInt("chapter") ?: 1
            StoryScreen(
                characterId = cid,
                chapter = ch,
                onChapterClear = { nav.popBackStack() },
                onGameOver = { _, _, _ -> nav.popBackStack() },
            )
        }
        composable(Routes.PLAY_CPU) {
            CpuBattleScreen(onGameOver = { score, maxChain, char ->
                nav.navigate("result?mode=cpuBattle&score=$score&maxChain=$maxChain&characterId=$char") {
                    popUpTo(Routes.TITLE) { inclusive = false }
                }
            })
        }
        composable(
            route = Routes.RANKING,
            arguments = listOf(navArgument("mode") { type = NavType.StringType; defaultValue = "endless" }),
        ) { entry ->
            val m = entry.arguments?.getString("mode") ?: "endless"
            RankingScreen(initialMode = m, onBack = { nav.popBackStack() })
        }
        composable(Routes.SAVE_SLOTS) { entry ->
            val app = entry.destination.route?.let { _ ->
                nav.context.applicationContext as com.example.myapp.App
            }
            SaveSlotScreen(
                onBack = { nav.popBackStack() },
                onLoad = { mode ->
                    // slot からロード → pendingResume に格納 → mode に応じたプレイ画面へ
                    val scope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.SupervisorJob() + kotlinx.coroutines.Dispatchers.IO)
                    scope.launch {
                        try {
                            val slot = app?.saveLoad?.loadSlot(1)
                            if (slot != null && app != null) {
                                app.setPendingResume(slot)
                                kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                                    val route = when (mode) {
                                        "SCORE_ATTACK" -> Routes.PLAY_SCORE_ATTACK
                                        "CPU_BATTLE" -> Routes.PLAY_CPU
                                        else -> Routes.PLAY_ENDLESS
                                    }
                                    nav.navigate(route) { popUpTo(Routes.TITLE) { inclusive = false } }
                                }
                            }
                        } catch (_: Exception) { /* 黙殺 */ }
                    }
                },
            )
        }
        composable(Routes.SETTINGS) {
            SettingsScreen(onBack = { nav.popBackStack() })
        }
        composable(
            route = Routes.RESULT,
            arguments = listOf(
                navArgument("mode") { type = NavType.StringType; defaultValue = "endless" },
                navArgument("score") { type = NavType.LongType; defaultValue = 0L },
                navArgument("maxChain") { type = NavType.IntType; defaultValue = 0 },
                navArgument("characterId") { type = NavType.StringType; defaultValue = "hina" },
            ),
        ) { entry ->
            val mode = entry.arguments?.getString("mode") ?: "endless"
            val score = entry.arguments?.getLong("score") ?: 0L
            val maxChain = entry.arguments?.getInt("maxChain") ?: 0
            val char = entry.arguments?.getString("characterId") ?: "hina"
            ResultScreen(
                mode = mode, score = score, maxChain = maxChain, characterId = char,
                onRetry = {
                    when (mode) {
                        "scoreAttack" -> nav.navigate(Routes.PLAY_SCORE_ATTACK) { popUpTo(Routes.TITLE) { inclusive = false } }
                        "cpuBattle" -> nav.navigate(Routes.PLAY_CPU) { popUpTo(Routes.TITLE) { inclusive = false } }
                        else -> nav.navigate(Routes.PLAY_ENDLESS) { popUpTo(Routes.TITLE) { inclusive = false } }
                    }
                },
                onBackToTitle = { nav.popBackStack(Routes.TITLE, inclusive = false) },
            )
        }
    }
}
