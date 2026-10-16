plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "dev.nativesteam.android"
    // Compose UI 1.12 (BOM 2026.09) requires compile SDK 37.
    compileSdk {
        version = release(37) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "dev.nativesteam.android"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        // Release code (R8, non-debuggable) signed with the debug key, for
        // installable cold-start benchmarks (scripts/coldstart.sh).
        create("benchmark") {
            initWith(getByName("release"))
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("release")
            isDebuggable = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    lint {
        checkReleaseBuilds = false
    }
}

kotlin {
    compilerOptions {
        optIn.addAll(
            "androidx.compose.material3.ExperimentalMaterial3Api",
            "androidx.compose.foundation.ExperimentalFoundationApi",
            "androidx.compose.foundation.layout.ExperimentalLayoutApi",
            "androidx.compose.ui.ExperimentalComposeUiApi",
        )
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.window)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.foundation)
    implementation(libs.compose.animation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.compose.material3.adaptive)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)
    implementation(libs.kotlinx.serialization.json)
}

/**
 * The app bundles the shared `data/snapshot.json` (the contract every Native Steam client
 * renders). Rather than keeping a hand-made copy in `src/main/assets`, this task copies the
 * file from the repo's `data/` directory into a generated assets folder at build time.
 */
abstract class BundleSnapshotTask : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val snapshot: RegularFileProperty

    @get:OutputDirectory
    abstract val outputDirectory: DirectoryProperty

    @TaskAction
    fun copy() {
        val out = outputDirectory.get().asFile
        out.deleteRecursively()
        out.mkdirs()
        snapshot.get().asFile.copyTo(out.resolve("snapshot.json"), overwrite = true)
    }
}

val bundleSnapshot = tasks.register<BundleSnapshotTask>("bundleSnapshot") {
    snapshot.set(rootProject.layout.projectDirectory.file("../../data/snapshot.json"))
}

androidComponents {
    onVariants { variant ->
        variant.sources.assets?.addGeneratedSourceDirectory(bundleSnapshot, BundleSnapshotTask::outputDirectory)
    }
}
