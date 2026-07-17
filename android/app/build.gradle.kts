plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.reload.prestreloajuda"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.reload.prestreloajuda"
        minSdk = 26
        targetSdk = 34
        // Versão sincronizada com Mac/Windows pela fonte única /VERSION.
        // Use scripts/bump-version.* para alterar (não edite à mão).
        versionCode = 10700
        versionName = "1.7.0"
    }

    // Chave de assinatura FIXA (commitada) — garante que toda build use a mesma assinatura,
    // permitindo instalar versões novas por cima das antigas.
    // Chave de teste/distribuição-direta; para a Play Store, troque por uma chave gerenciada.
    signingConfigs {
        getByName("debug") {
            storeFile = file("../keystore/prestrelo.keystore")
            storePassword = "prestrelo-2026"
            keyAlias = "prestrelo"
            keyPassword = "prestrelo-2026"
        }
        create("release") {
            storeFile = file("../keystore/prestrelo.keystore")
            storePassword = "prestrelo-2026"
            keyAlias = "prestrelo"
            keyPassword = "prestrelo-2026"
        }
    }

    buildTypes {
        // release = versão DISTRIBUÍDA (BuildConfig.DEBUG=false → bloqueio de versão ativo).
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
        }
        // debug = desenvolvimento local (BuildConfig.DEBUG=true → NUNCA bloqueia).
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true // expõe BuildConfig.VERSION_NAME para o rodapé de versão
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.2")
    implementation("androidx.savedstate:savedstate-ktx:1.2.1")
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
}
