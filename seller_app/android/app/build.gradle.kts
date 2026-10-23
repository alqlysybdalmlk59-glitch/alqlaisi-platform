plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStorePath = System.getenv("ALQLAISI_SELLER_KEYSTORE_PATH")
val releaseStorePassword = System.getenv("ALQLAISI_SELLER_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("ALQLAISI_SELLER_KEY_ALIAS")
val releaseKeyPassword = System.getenv("ALQLAISI_SELLER_KEY_PASSWORD")
val releaseSigningConfigured =
    listOf(releaseStorePath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword)
        .all { !it.isNullOrBlank() } &&
        releaseStorePath?.let { file(it).isFile } == true

android {
    namespace = "com.alqlaisi.seller"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.alqlaisi.seller"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Never sign a production artifact using Android's publicly-known debug key.
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        if (!releaseSigningConfigured) {
            throw GradleException(
                "Seller release signing is not configured. Set ALQLAISI_SELLER_KEYSTORE_PATH, " +
                    "ALQLAISI_SELLER_KEYSTORE_PASSWORD, ALQLAISI_SELLER_KEY_ALIAS and " +
                    "ALQLAISI_SELLER_KEY_PASSWORD. Debug signing is intentionally not used for releases."
            )
        }
    }
}

tasks.configureEach {
    if (name.contains("Release") &&
        (name.startsWith("assemble") || name.startsWith("bundle") || name.startsWith("package"))
    ) {
        dependsOn(verifyReleaseSigning)
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
