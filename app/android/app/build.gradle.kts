import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
val signingDirectory = providers.environmentVariable("LINGODESK_SIGNING_DIR").orNull?.let { file(it) }
    ?: rootProject.file("../../.signing")
val signingProperties = Properties().apply {
    signingDirectory.resolve("key.properties").inputStream().use { load(it) }
}
android {
    namespace = "com.lecsync.desk"
    compileSdk = 37
    buildToolsVersion = "37.0.0"
    ndkVersion = "26.1.10909125"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.lecsync.desk"
        minSdk = 29
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk { abiFilters.clear(); abiFilters.add(if (project.hasProperty("testX64")) "x86_64" else "arm64-v8a") }
    }
    signingConfigs {
        create("delivery") {
            storeFile = signingDirectory.resolve("release.jks")
            storePassword = signingProperties.getProperty("storePassword")
            keyAlias = "desk"
            keyPassword = signingProperties.getProperty("keyPassword")
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("delivery"); isDebuggable = false }
        debug { signingConfig = signingConfigs.getByName("delivery") }
    }
    packaging { jniLibs { useLegacyPackaging = false } }
}
kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
flutter { source = "../.." }

dependencies {
    implementation("com.google.mlkit:translate:17.0.3")
    testImplementation("junit:junit:4.13.2")
}
