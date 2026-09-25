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
    project.evaluationDependsOn(":app")
}

allprojects {
    fun forceSdk(project: Project) {
        project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.let { android ->
            if (android.compileSdkVersion != null && 
                (android.compileSdkVersion!!.startsWith("android-") && 
                 android.compileSdkVersion!!.substringAfter("android-").toIntOrNull()?.let { it < 36 } == true)) {
                android.compileSdkVersion("android-36")
            } else if (android.compileSdkVersion == null || android.compileSdkVersion == "30" || android.compileSdkVersion == "34") {
                android.compileSdkVersion("android-36")
            }

            if (android is com.android.build.gradle.LibraryExtension) {
                if (android.namespace == null || android.namespace!!.isBlank()) {
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
        project.afterEvaluate {
            forceSdk(project)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
