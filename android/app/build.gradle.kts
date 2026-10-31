plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}


// Signing material is supplied only to the build process, never committed.
val releaseSigning = listOf(
    "IDEA_INBOX_KEYSTORE", "IDEA_INBOX_KEY_ALIAS",
    "IDEA_INBOX_STORE_PASSWORD", "IDEA_INBOX_KEY_PASSWORD"
).associateWith { System.getenv(it) }
val hasReleaseSigning = releaseSigning.values.all { !it.isNullOrBlank() }
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") } && !hasReleaseSigning) {
        throw GradleException("Release signing requires IDEA_INBOX_KEYSTORE, IDEA_INBOX_KEY_ALIAS, IDEA_INBOX_STORE_PASSWORD and IDEA_INBOX_KEY_PASSWORD.")
    }
}

android {
    namespace = "dev.ideainbox.idea_inbox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.ideainbox.idea_inbox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigning.getValue("IDEA_INBOX_KEYSTORE")!!)
                keyAlias = releaseSigning.getValue("IDEA_INBOX_KEY_ALIAS")
                storePassword = releaseSigning.getValue("IDEA_INBOX_STORE_PASSWORD")
                keyPassword = releaseSigning.getValue("IDEA_INBOX_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) signingConfig = signingConfigs.getByName("release")
        }
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
