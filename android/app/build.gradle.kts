plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ✅ ปรับให้ตรงกับที่ Firebase ต้องการ
    ndkVersion = "27.0.12077973"

    namespace = "com.example.delivery_frontend"
    compileSdk = flutter.compileSdkVersion

    // ✅ ใช้ Java 17 (ใหม่กว่า ปลอดภัยกว่า)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.delivery_frontend"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ✅ ถ้ายังไม่ได้เซ็นแอปจริง ให้ใช้ debug key ชั่วคราว
            signingConfig = signingConfigs.getByName("debug")

            // ✅ ปิดการ minify (ถ้าอยากลดขนาดสามารถเปิดได้ภายหลัง)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
