package com.newsblur.activity

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class InitActivityManifestTest {
    @Test
    fun initActivity_supports_daily_briefing_app_links() {
        val manifestFile =
            sequenceOf(
                File("app/src/main/AndroidManifest.xml"),
                File("src/main/AndroidManifest.xml"),
            ).firstOrNull(File::exists)

        val resolvedManifestFile = manifestFile ?: error("Could not locate app AndroidManifest.xml")
        val manifest =
            DocumentBuilderFactory
                .newInstance()
                .newDocumentBuilder()
                .parse(resolvedManifestFile)
        val activities = manifest.getElementsByTagName("activity")
        var foundDailyBriefingAppLink = false

        for (index in 0 until activities.length) {
            val activity = activities.item(index) as? Element ?: continue
            if (activity.getAttribute("android:name") != ".activity.InitActivity") continue

            val intentFilters = activity.getElementsByTagName("intent-filter")
            for (filterIndex in 0 until intentFilters.length) {
                val filter = intentFilters.item(filterIndex) as? Element ?: continue
                val dataElements = filter.getElementsByTagName("data")

                for (dataIndex in 0 until dataElements.length) {
                    val data = dataElements.item(dataIndex) as? Element ?: continue
                    val host = data.getAttribute("android:host")
                    val pathPrefix = data.getAttribute("android:pathPrefix")
                    if ((host == "newsblur.com" || host == "www.newsblur.com") && pathPrefix == "/briefing") {
                        foundDailyBriefingAppLink = true
                        break
                    }
                }

                if (foundDailyBriefingAppLink) break
            }
        }

        assertTrue("InitActivity should register a /briefing app link", foundDailyBriefingAppLink)
    }
}
