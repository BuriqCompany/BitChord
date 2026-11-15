plugins {
    kotlin("multiplatform") version "2.4.10"
}

kotlin {
    val iosTargets = listOf(iosArm64(), iosSimulatorArm64())
    iosTargets.forEach { target ->
        target.binaries.framework {
            baseName = "BitChordShared"
            isStatic = true
        }
    }
    applyDefaultHierarchyTemplate()

    sourceSets {
        val iosMain by getting {
            dependencies {
                implementation("io.ktor:ktor-client-darwin:3.5.2")
                implementation("io.ktor:ktor-client-content-negotiation:3.5.2")
                implementation("io.ktor:ktor-serialization-kotlinx-json:3.5.2")
                implementation("com.github.MetrolistGroup.innertubex:innertubex:v0.7.0")
            }
        }
    }
}
