plugins {
    id("com.android.application")

    // Kotlin Android plugin
    id("org.jetbrains.kotlin.android")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration

    // Flutter Gradle Plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nubify.app"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    //=============================
    // JAVA / DESUGARING
    //=============================
    compileOptions {
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nubify.app"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

//=============================
// KOTLIN
//=============================
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

//=============================
// DESUGARING DEPENDENCY
//=============================
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

//=============================
// FLUTTER
//=============================
flutter {
    source = "../.."
}