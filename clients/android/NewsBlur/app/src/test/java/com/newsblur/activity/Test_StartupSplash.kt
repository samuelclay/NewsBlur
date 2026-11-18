package com.newsblur.activity

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

class Test_StartupSplash {
    // Test_StartupSplash.kt: every launcher entry must use the same complete splash artwork. A new entry
    // using a generic Material theme falls back to the adaptive app icon, whose system mask crops the sun.
    @Test
    fun test_launcher_entries_resolve_the_dedicated_splash_artwork() {
        val main = xml("src/main/AndroidManifest.xml")
        val capture = xml("src/storecapture/AndroidManifest.xml")
        val styles =
            File("src/main/res/values")
                .listFiles()
                .orEmpty()
                .filter { it.extension == "xml" }
                .flatMap { xml(it.path).children("style") }
                .associateBy { it.getAttribute("name") }

        fun splashIcon(theme: String): String? {
            var name = theme.removePrefix("@style/")
            val seen = mutableSetOf<String>()
            while (seen.add(name)) {
                val style = styles[name] ?: return null
                style
                    .children("item")
                    .firstOrNull {
                        it.getAttribute("name").removePrefix("android:") == "windowSplashScreenAnimatedIcon"
                    }?.let { return it.textContent.trim() }
                name = style.getAttribute("parent").removePrefix("@style/").ifEmpty { name.substringBeforeLast('.', "") }
            }
            return null
        }
        val mainApplication = main.children("application").single()
        val mainActivities = mainApplication.children("activity").associateBy { it.getAttribute("android:name") }
        val canonical = splashIcon(mainActivities.getValue(".activity.InitActivity").getAttribute("android:theme"))
        assertNotNull("InitActivity needs dedicated splash artwork", canonical)

        for (manifest in listOf(main, capture)) {
            val application = manifest.children("application").single()
            val activities = mainActivities + application.children("activity").associateBy { it.getAttribute("android:name") }
            val entries = application.children("activity") + application.children("activity-alias")
            for (entry in entries.filter { it.hasLauncherIntent() }) {
                val target =
                    if (entry.tagName ==
                        "activity-alias"
                    ) {
                        activities.getValue(entry.getAttribute("android:targetActivity"))
                    } else {
                        entry
                    }
                val theme =
                    target.getAttribute("android:theme").ifEmpty {
                        application.getAttribute("android:theme").ifEmpty { mainApplication.getAttribute("android:theme") }
                    }
                assertEquals("${entry.getAttribute("android:name")} falls back to a cropped adaptive icon", canonical, splashIcon(theme))
            }
        }
    }

    private fun xml(path: String): Element =
        DocumentBuilderFactory
            .newInstance()
            .newDocumentBuilder()
            .parse(File(path))
            .documentElement

    private fun Element.children(tag: String): List<Element> =
        (0 until childNodes.length)
            .mapNotNull { childNodes.item(it) as? Element }
            .filter { it.tagName == tag }

    private fun Element.hasLauncherIntent(): Boolean =
        children("intent-filter").any { filter ->
            filter.children("action").any { it.getAttribute("android:name") == "android.intent.action.MAIN" } &&
                filter.children("category").any { it.getAttribute("android:name") == "android.intent.category.LAUNCHER" }
        }
}
