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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    project.plugins.configureEach {
        if (this is com.android.build.gradle.LibraryPlugin) {
            project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
                if (namespace == null) {
                    namespace = project.group.toString()
                }
            }
        }
        if (this is com.android.build.gradle.AppPlugin) {
            project.extensions.findByType(com.android.build.gradle.AppExtension::class.java)?.apply {
                if (namespace == null) {
                    namespace = project.group.toString()
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
