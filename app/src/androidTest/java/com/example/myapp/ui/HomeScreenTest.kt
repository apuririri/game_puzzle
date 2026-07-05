package com.example.myapp.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.myapp.MainActivity
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Compose UI Test の雛形（起動スモーク。Web 版 healthcheck.spec.ts 相当）。
 * testTag のみで操作する（座標タップ禁止 / 絶対規約10）。
 */
@RunWith(AndroidJUnit4::class)
class HomeScreenTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun app_launches_and_shows_home() {
        composeRule.onNodeWithTag("home_root").assertIsDisplayed()
        composeRule.onNodeWithTag("home_memo_input").assertIsDisplayed()
        composeRule.onNodeWithTag("home_add_button").assertIsDisplayed()
    }

    @Test
    fun add_memo_appears_in_list() {
        composeRule.onNodeWithTag("home_memo_input").performTextInput("テストメモ")
        composeRule.onNodeWithTag("home_add_button").performClick()
        composeRule.waitUntil(timeoutMillis = 5_000) {
            composeRule.onAllNodes(androidx.compose.ui.test.hasText("テストメモ"))
                .fetchSemanticsNodes().isNotEmpty()
        }
        composeRule.onNodeWithText("テストメモ").assertIsDisplayed()
    }
}
