allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround for https://github.com/material-foundation/flutter-packages/issues (dynamic_color
// 1.9.0's android/build.gradle.kts references the `kotlin { }` extension without applying the
// Kotlin Android Gradle plugin, which fails to resolve during `assembleRelease`. Force-apply the
// plugin to that specific module only, before its own build script evaluates.
subprojects {
    if (project.name == "dynamic_color") {
        pluginManager.apply("org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
