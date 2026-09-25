allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // home_widget 0.9.0, Android tarafında DİNAMİK sürüm kullanıyor:
    //     implementation "androidx.glance:glance-appwidget:1.+"
    //     implementation "androidx.work:work-runtime-ktx:2.+"
    //     implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.+"
    //
    // "1.+" ifadesi, Google her yeni sürüm yayınladığında derlemeyi kırıyor.
    // Örneğin glance-appwidget 1.3.0-alpha02 sürümü AGP 9.1.0+ gerektiriyor;
    // projede ise AGP 8.11.1 kullanılıyor ve derleme şu hatayla duruyor:
    //     Dependency 'androidx.glance:glance-appwidget:1.3.0-alpha02' requires
    //     Android Gradle plugin 9.1.0 or higher.
    //
    // Sürümleri burada sabitleyerek (force) bağımlılığı zamanla bozulmaktan
    // kurtarıyor ve mevcut AGP 8.11.1 ile uyumlu, kararlı sürümleri kullanıyoruz.
    configurations.all {
        resolutionStrategy {
            force("androidx.glance:glance-appwidget:1.1.1")
            force("androidx.glance:glance:1.1.1")
            force("androidx.work:work-runtime-ktx:2.9.1")
            force("androidx.work:work-runtime:2.9.1")
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}