package com.example.myapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import com.example.myapp.ui.navigation.AppNavHost
import com.example.myapp.ui.theme.MyAppTheme

class MainActivity : ComponentActivity() {
    @OptIn(ExperimentalComposeUiApi::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MyAppTheme {
                Surface(
                    modifier = Modifier
                        .fillMaxSize()
                        // 必須: testTag を UIAutomator/Maestro の resource-id として公開する（修正方針 §6-6）。
                        // これを外すと Maestro の testTag 参照が全滅する。削除禁止。
                        .semantics { testTagsAsResourceId = true }
                ) {
                    AppNavHost()
                }
            }
        }
    }
}
