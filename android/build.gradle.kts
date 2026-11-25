import com.android.build.api.dsl.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://gitlab.com/api/v4/projects/50747855/packages/maven") }
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

    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            if ((compileSdk ?: 0) < 36) {
                compileSdk = 36
            }
        }
    }

    if (project.name != "app") {
        tasks.withType<KotlinJvmCompile>().configureEach {
            val javaTaskName = name.replace("Kotlin", "JavaWithJavac")
            val target = project.tasks.findByName(javaTaskName)
                ?.let { (it as? JavaCompile)?.targetCompatibility }
                ?.takeIf { it.isNotBlank() }
                ?: "11"
            compilerOptions.jvmTarget.set(JvmTarget.fromTarget(target))
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
