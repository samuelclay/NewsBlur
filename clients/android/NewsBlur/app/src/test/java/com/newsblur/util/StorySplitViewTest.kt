package com.newsblur.util

import com.newsblur.activity.ItemsList
import com.newsblur.activity.Reading
import org.junit.Assert.assertEquals
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
