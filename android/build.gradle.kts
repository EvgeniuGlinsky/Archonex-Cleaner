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

// `disk_space_2` writes its Android side in Kotlin and configures the Kotlin
// extension, but its own `build.gradle` applies only `com.android.library` — it
// relies on the host project having put the Kotlin plugin on every subproject,
// which the Flutter template stopped doing. Without this the release build dies
// evaluating that file: "Could not find method kotlin()".
//
// Applied from here rather than from `afterEvaluate`, because the failure is in
// the plugin's script itself and anything deferred runs after it.
subprojects {
    if (name == "disk_space_2") {
        apply(plugin = "org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
