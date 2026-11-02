import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "app.rokapi"
    compileSdk = 35

    defaultConfig {
        applicationId = "app.rokapi"
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        debug {
            buildConfigField("String", "ROOT_URL", "\"http://10.0.2.2:3000\"")
        }

        release {
            isMinifyEnabled = false
            buildConfigField("String", "ROOT_URL", "\"http://10.0.2.2:3000\"")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        named("main") { java { srcDirs("src/main/kotlin") } }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(17)
    }
}

dependencies {
    implementation("dev.hotwire:core:1.3.2")
    implementation("dev.hotwire:navigation-fragments:1.3.2")
    implementation("com.google.android.material:material:1.12.0")
}
