import java.io.FileInputStream
import java.util.Properties

// Capítulo 40: a chave de upload da loja. O android/key.properties aponta
// para o keystore e guarda as senhas; nenhum dos dois entra no git (os dois
// estão no .gitignore). No CI, o workflow escreve os dois a partir dos
// segredos do repositório. Sem o arquivo, o build de release continua
// assinado com a chave de depuração, como antes, e não serve para a loja.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Cópia pública do livro: os plugins do Firebase só entram quando o
// flutterfire configure já criou um google-services.json (capítulo 38). Sem
// ele, o app compila e roda sem o Firebase; no livro, os dois plugins ficam
// no bloco plugins acima, sem condição.
if (listOf("dev", "staging", "prod").any { file("src/$it/google-services.json").exists() }) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

android {
    namespace = "com.zayitbrazil.mobile_tarefas_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // O identificador da loja não deriva do nome do pacote Dart nem do
        // namespace do código Kotlin (capítulos 15 e 26).
        applicationId = "com.zayitbrazil.mobiletarefas"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Capítulo 26: um flavor por ambiente, instaláveis lado a lado. O nome na
    // tela vem de src/<flavor>/res/values/strings.xml: o resValue falha por
    // padrão a partir do AGP 9.
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
        }
        create("prod") {
            dimension = "environment"
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
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
