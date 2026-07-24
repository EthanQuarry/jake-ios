plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.android")
  id("maven-publish")
}

group = "ai.tryjake"
version = "0.1.0"

android {
  namespace = "ai.tryjake.sdk"
  compileSdk = 35

  defaultConfig {
    minSdk = 23
    consumerProguardFiles("consumer-rules.pro")
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions {
    jvmTarget = "17"
  }

  publishing {
    singleVariant("release") {
      withSourcesJar()
    }
  }
}

val androidJavadocsJar by tasks.registering(Jar::class) {
  archiveClassifier.set("javadoc")
  from(rootProject.file("README.md"))
}

dependencies {
  implementation("androidx.activity:activity-ktx:1.10.0")
  implementation("androidx.security:security-crypto:1.1.0-alpha06")
}

publishing {
  publications {
    register<MavenPublication>("release") {
      groupId = "ai.tryjake"
      artifactId = "jake-sdk"
      version = project.version.toString()
      afterEvaluate {
        from(components["release"])
        artifact(androidJavadocsJar)
      }

      pom {
        name.set("Jake SDK for Android")
        description.set("Jake hosted support Messenger for Android.")
        url.set("https://github.com/EthanQuarry/jake-ios")
        inceptionYear.set("2026")

        licenses {
          license {
            name.set("MIT License")
            url.set("https://opensource.org/license/mit")
            distribution.set("repo")
          }
        }

        developers {
          developer {
            id.set("ethanquarry")
            name.set("Ethan Quarry")
            email.set("me@ethanquarry.com")
            organization.set("Jake")
            organizationUrl.set("https://tryjake.ai")
          }
        }

        scm {
          connection.set("scm:git:https://github.com/EthanQuarry/jake-ios.git")
          developerConnection.set("scm:git:ssh://git@github.com/EthanQuarry/jake-ios.git")
          url.set("https://github.com/EthanQuarry/jake-ios")
          tag.set(project.version.toString())
        }
      }
    }
  }

  repositories {
    maven {
      name = "staging"
      url = rootProject.layout.buildDirectory.dir("staging-deploy").get().asFile.toURI()
    }
  }
}
