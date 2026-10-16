// AGP 9 compiles Kotlin itself; declaring the Kotlin plugins here (not applied) pins the
// Kotlin Gradle plugin version that AGP's built-in Kotlin support uses.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
