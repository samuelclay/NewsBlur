package com.newsblur.util

import com.newsblur.activity.ItemsList
import com.newsblur.activity.Reading
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import java.lang.reflect.Modifier
import javax.xml.parsers.DocumentBuilderFactory

class StorySplitViewTest {
    private val manifest by lazy {
        val manifestFile =
            sequenceOf(
                File("app/src/main/AndroidManifest.xml"),
                File("src/main/AndroidManifest.xml"),
            ).firstOrNull(File::exists) ?: error("Could not locate app AndroidManifest.xml")
        DocumentBuilderFactory
            .newInstance()
            .newDocumentBuilder()
            .parse(manifestFile)
    }

    private fun manifestActivityClasses(): List<Class<*>> {
        val activities = manifest.getElementsByTagName("activity")
        return (0 until activities.length)
            .mapNotNull { index -> activities.item(index) as? Element }
            .map { activity -> activity.getAttribute("android:name") }
            .map { name -> Class.forName("com.newsblur$name", false, javaClass.classLoader) }
    }

    private fun concreteSubclassesOf(base: Class<*>): Set<Class<*>> =
        manifestActivityClasses()
            .filter { base.isAssignableFrom(it) && !Modifier.isAbstract(it.modifiers) }
            .toSet()

    @Test
    fun everyStoryList_splitsWithTheReader() {
        // A story list missing from StorySplitView.kt would open full width on tablets.
        assertEquals(concreteSubclassesOf(ItemsList::class.java), StorySplitView.STORY_LIST_ACTIVITIES.toSet())
    }

    @Test
    fun everyReader_opensBesideItsStoryList() {
        // A reader missing from StorySplitView.kt would cover its story list on tablets.
        assertEquals(concreteSubclassesOf(Reading::class.java), StorySplitView.READING_ACTIVITIES.toSet())
    }

    @Test
    fun rules_installOnlyWhereAWindowCanReachSplitWidth() {
        // A 411dp phone and a flip phone's 412dp inner screen never split, so they keep the
        // phone flow with no embedded containers. A 600dp tablet or an opened foldable does.
        assertFalse(StorySplitView.shouldInstallRules(smallestScreenWidthDp = 411))
        assertFalse(StorySplitView.shouldInstallRules(smallestScreenWidthDp = 412))
        assertFalse(StorySplitView.shouldInstallRules(smallestScreenWidthDp = 599))
        assertTrue(StorySplitView.shouldInstallRules(smallestScreenWidthDp = 600))
        assertTrue(StorySplitView.shouldInstallRules(smallestScreenWidthDp = 800))
    }

    @Test
    fun splitPane_requiresAnEmbeddedMultiWindowActivity() {
        assertTrue(StorySplitView.isSplitPane(isInMultiWindowMode = true) { true })
        // An always expanded screen (Daily Briefing's reader on a phone) is embedded but fills the window.
        assertFalse(StorySplitView.isSplitPane(isInMultiWindowMode = false) { true })
        // System split screen beside another app is multi-window but not embedded.
        assertFalse(StorySplitView.isSplitPane(isInMultiWindowMode = true) { false })
        // Full screen activities never ask the embedding controller at all.
        assertFalse(StorySplitView.isSplitPane(isInMultiWindowMode = false) { error("embedding checked for a full screen activity") })
    }

    @Test
    fun manifest_enablesSplitsAndDeclaresThePlaceholder() {
        val properties = manifest.getElementsByTagName("property")
        val splitsEnabled =
            (0 until properties.length)
                .mapNotNull { index -> properties.item(index) as? Element }
                .any { property ->
                    property.getAttribute("android:name") == "android.window.PROPERTY_ACTIVITY_EMBEDDING_SPLITS_ENABLED" &&
                        property.getAttribute("android:value") == "true"
                }
        assertTrue("AndroidManifest.xml must enable activity embedding splits", splitsEnabled)
        assertTrue(
            "ReadingPlaceholder must be declared for the empty reader pane",
            manifestActivityClasses().any { it.simpleName == "ReadingPlaceholder" },
        )
    }
}
