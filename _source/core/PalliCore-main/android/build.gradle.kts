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

// Pull every plugin up to the compileSdk the newest one demands.
//
// `flutter_plugin_android_lifecycle` (via image_picker) now requires anything
// depending on it to compile against API 36, while `file_picker` 8.x still
// declares 34 — so `assembleDebug` fails outright. Upgrading file_picker to a
// release that declares 36 drags win32 up with it and breaks `share_plus` and
// `flutter_secure_storage` in turn, so the whole plugin set is raised here
// instead. compileSdk only widens the APIs available at compile time; it does
// not touch targetSdk or minSdk, so runtime behaviour and device support are
// unchanged.
//
// This is the same helper PalliConnect already uses — kept identical so the two
// apps' Android builds do not drift. `evaluationDependsOn(":app")` above means
// some projects are already evaluated by the time this runs, hence the
// `state.executed` guard rather than a bare `afterEvaluate`.
allprojects {
    fun forceSdk(project: Project) {
        project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.let { android ->
            val current = android.compileSdkVersion
            val currentApi = current?.substringAfter("android-")?.toIntOrNull()
            if (current == null || currentApi == null || currentApi < 36) {
                android.compileSdkVersion("android-36")
            }

            // Old library plugins predate the namespace requirement, which AGP 8
            // refuses to build without.
            if (android is com.android.build.gradle.LibraryExtension) {
                if (android.namespace.isNullOrBlank()) {
                    android.namespace = project.group.toString().ifBlank {
                        "dev.pub.${project.name.replace("-", "_")}"
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        forceSdk(project)
    } else {
        project.afterEvaluate { forceSdk(project) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
