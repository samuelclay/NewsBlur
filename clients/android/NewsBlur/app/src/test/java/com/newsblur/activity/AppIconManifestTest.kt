package com.newsblur.activity

import com.newsblur.util.AppIconManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

class AppIconManifestTest {
    @Test
    fun appIconLauncherAliases_matchCatalog() {
        val manifest = parseManifest()
        val aliases = manifest.getElementsByTagName("activity-alias")
        val launcherAliases = mutableMapOf<String, Element>()

        for (index in 0 until aliases.length) {
            val alias = aliases.item(index) as? Element ?: continue
            if (alias.hasMainLauncherIntent()) {
                launcherAliases[alias.getAttribute("android:name")] = alias
            }
        }

        assertEquals(AppIconManager.flavors.size, launcherAliases.size)

        AppIconManager.flavors.forEachIndexed { index, flavor ->
            val alias = launcherAliases[flavor.aliasSuffix]
            assertNotNull("Missing launcher alias for ${flavor.id}", alias)
            alias!!
            assertEquals(".activity.InitActivity", alias.getAttribute("android:targetActivity"))
            assertEquals("@mipmap/app_icon_${flavor.id.replace("-", "_")}", alias.getAttribute("android:icon"))
            assertEquals(if (index == 0) "true" else "false", alias.getAttribute("android:enabled"))
        }
    }

    @Test
    fun appIconAdaptiveIcons_useInsetForegrounds() {
        AppIconManager.flavors.forEach { flavor ->
            val resourceName = flavor.id.replace("-", "_")
            val adaptiveIcon = parseXml("app/src/main/res/mipmap-anydpi/app_icon_$resourceName.xml")
            val foreground = adaptiveIcon.getElementsByTagName("foreground").item(0) as Element
            val background = adaptiveIcon.getElementsByTagName("background").item(0) as Element

            assertEquals("@android:color/transparent", background.getAttribute("android:drawable"))
            assertEquals("@drawable/app_icon_${resourceName}_foreground", foreground.getAttribute("android:drawable"))

            val foregroundDrawable = parseXml("app/src/main/res/drawable/app_icon_${resourceName}_foreground.xml")
            assertEquals("inset", foregroundDrawable.tagName)
            assertEquals("8dp", foregroundDrawable.getAttribute("android:inset"))
            assertEquals("@drawable/app_icon_$resourceName", foregroundDrawable.getAttribute("android:drawable"))
        }
    }

    private fun parseManifest(): Element {
        val manifestFile =
            sequenceOf(
                File("app/src/main/AndroidManifest.xml"),
                File("src/main/AndroidManifest.xml"),
            ).firstOrNull(File::exists)

        val resolvedManifestFile = manifestFile ?: error("Could not locate app AndroidManifest.xml")
        return parseXml(resolvedManifestFile.path)
    }

    private fun parseXml(path: String): Element {
        val file =
            sequenceOf(
                File(path),
                File(path.removePrefix("app/")),
            ).firstOrNull(File::exists)

        val resolvedFile = file ?: error("Could not locate $path")
        return DocumentBuilderFactory
            .newInstance()
            .newDocumentBuilder()
            .parse(resolvedFile)
            .documentElement
    }

    private fun Element.hasMainLauncherIntent(): Boolean {
        val intentFilters = getElementsByTagName("intent-filter")
        for (filterIndex in 0 until intentFilters.length) {
            val filter = intentFilters.item(filterIndex) as? Element ?: continue
            val hasMainAction = filter.hasChildWithAttribute("action", "android:name", "android.intent.action.MAIN")
            val hasLauncherCategory =
                filter.hasChildWithAttribute("category", "android:name", "android.intent.category.LAUNCHER")
            if (hasMainAction && hasLauncherCategory) return true
        }
        return false
    }

    private fun Element.hasChildWithAttribute(
        tagName: String,
        attributeName: String,
        attributeValue: String,
    ): Boolean {
        val children = getElementsByTagName(tagName)
        for (index in 0 until children.length) {
            val child = children.item(index) as? Element ?: continue
            if (child.getAttribute(attributeName) == attributeValue) return true
        }
        return false
    }
}
