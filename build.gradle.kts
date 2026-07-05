// ルートビルドスクリプト。バージョンは gradle/libs.versions.toml（Version Catalog）で一元管理。
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.ksp) apply false
}
