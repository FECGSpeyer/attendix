allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins that still compile against an older Android API (file_picker 8.x:
// 34) fail AGP's AAR metadata check as soon as one of their dependencies
// needs a newer one (flutter_plugin_android_lifecycle: 36). Compile every
// plugin against at least the app's compileSdk. That only changes which APIs
// are visible at compile time, not minSdk or targetSdk. Must stay above the
// evaluationDependsOn block: afterEvaluate cannot be added to a project that
// is already evaluated.
subprojects {
    if (path != ":app") {
        afterEvaluate {
            val library = extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            val appCompileSdk = rootProject.project(":app").extensions
                .findByType(com.android.build.api.dsl.ApplicationExtension::class.java)
                ?.compileSdk
            val pluginCompileSdk = library?.compileSdk
            if (library != null && appCompileSdk != null &&
                pluginCompileSdk != null && pluginCompileSdk < appCompileSdk
            ) {
                library.compileSdk = appCompileSdk
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
