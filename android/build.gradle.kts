allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Современный и безопасный способ переопределения compileSdk для всех Android-плагинов в AGP 8+
subprojects {
    plugins.withId("com.android.library") {
        configure<com.android.build.api.dsl.LibraryExtension> {
            compileSdk = 36
        }
    }
    plugins.withId("com.android.application") {
        configure<com.android.build.api.dsl.ApplicationExtension> {
            compileSdk = 36
        }
    }
    // Плагины (например file_picker) задают свой compileSdk в собственном
    // build.gradle уже после применения плагина — принудительно поднимаем до 36
    // после оценки проекта, иначе AAR-метаданные требуют API 36 и сборка падает.
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = 36
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = rootProject.layout.buildDirectory.dir(project.name).get()
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}