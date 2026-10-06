package com.newsblur.util

import android.app.Activity
import android.content.res.Configuration
import android.graphics.Rect
import android.util.DisplayMetrics
import androidx.window.embedding.SplitAttributes
import com.newsblur.activity.ItemsList
import com.newsblur.activity.Reading
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import java.lang.reflect.Modifier
import javax.xml.parsers.DocumentBuilderFactory

class StorySplitViewTest {
    @Test
    fun pairedReaderCannotToggleFullscreenInANarrowWholeWindow() {
        withReaderSplitWindow(widthDp = 599) { reading ->
            assertFalse(StorySplitView.canToggleReaderFullscreen(reading))
        }
    }

    @Test
    fun pairedReaderCannotToggleFullscreenWhenTheWholeWindowSmallestWidthIsNarrow() {
        withReaderSplitWindow(widthDp = 840, heightDp = 599) { reading ->
            assertFalse(StorySplitView.canToggleReaderFullscreen(reading))
        }
    }

    @Test
    fun expandedReaderCanToggleFullscreenAt600dpDespiteItsNarrowConfiguration() {
        withReaderSplitWindow(widthDp = 600) { reading ->
            assertTrue(StorySplitView.canToggleReaderFullscreen(reading))
        }
    }

    @Test
    fun sideBySidePortraitReaderCanToggleFullscreenWith480dpPaneMetrics() {
        withReaderSplitWindow(widthDp = 480, heightDp = 1280, inSplit = true) { reading ->
            assertTrue(StorySplitView.canToggleReaderFullscreen(reading))
        }
    }

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
            // StorySplitViewTest.kt resolves manifest shorthand (".activity.Foo") against the app package.
            .map { name -> if (name.startsWith(".")) "com.newsblur$name" else name }
            .map { name -> Class.forName(name, false, javaClass.classLoader) }
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
    fun fullscreenReadingExpandsOnlyTheArticleAndRestoresTheOriginalSplit() {
        val defaults = SplitAttributes.Builder()
            .setSplitType(SplitAttributes.SplitType.ratio(StorySplitView.STORY_LIST_SPLIT_RATIO))
            .setLayoutDirection(SplitAttributes.LayoutDirection.LOCALE)
            .build()
        assertEquals(
            SplitAttributes.SplitType.SPLIT_TYPE_EXPAND,
            StorySplitView.calculateSplitAttributes("story_list_reader", true, true, defaults).splitType,
        )
        assertEquals(defaults, StorySplitView.calculateSplitAttributes("story_list_reader", true, false, defaults))
        // StorySplitViewTest.kt keeps the empty reader and unrelated split rules unchanged.
        for (tag in listOf("empty_reader", "other_rule", null)) {
            assertEquals(defaults, StorySplitView.calculateSplitAttributes(tag, true, true, defaults))
        }
    }

    @Test
    fun leavingFullscreenNeverForcesColumnsIntoAFoldedOrNarrowWindow() {
        val defaults = SplitAttributes.Builder()
            .setSplitType(SplitAttributes.SplitType.ratio(StorySplitView.STORY_LIST_SPLIT_RATIO))
            .build()
        for (fullscreen in listOf(true, false)) {
            assertEquals(
                SplitAttributes.SplitType.SPLIT_TYPE_EXPAND,
                StorySplitView.calculateSplitAttributes("story_list_reader", false, fullscreen, defaults).splitType,
            )
        }
        assertEquals(defaults, StorySplitView.calculateSplitAttributes("story_list_reader", true, false, defaults))
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
        // An always expanded screen (Daily Briefing's reader on a tablet) is embedded but fills the window.
        assertFalse(StorySplitView.isSplitPane(isInMultiWindowMode = false) { true })
        // System split screen beside another app is multi-window but not embedded.
        assertFalse(StorySplitView.isSplitPane(isInMultiWindowMode = true) { false })
        // Full screen activities never ask the embedding controller at all.
        assertFalse(StorySplitView.isSplitPane(isInMultiWindowMode = false) { error("embedding checked for a full screen activity") })
    }

    @Test
    fun splitMembership_countsOnlySideBySidePanes() {
        assertTrue(StorySplitView.isSideBySide(listOf(SplitAttributes.SplitType.ratio(StorySplitView.STORY_LIST_SPLIT_RATIO))))
        // A folded or narrowed window can keep the split with its containers stacked.
        assertFalse(StorySplitView.isSideBySide(listOf(SplitAttributes.SplitType.SPLIT_TYPE_EXPAND)))
        assertFalse(StorySplitView.isSideBySide(emptyList()))
    }

    @Test
    fun splitMembership_trustsSplitInfoOverWindowingMode() {
        // System split screen beside another app: multi-window and embedded, but no NewsBlur split.
        assertFalse(StorySplitView.resolveInSplit(reportedInSplit = false) { true })
        assertTrue(StorySplitView.resolveInSplit(reportedInSplit = true) { false })
        // Before splitInfoList first reports, the windowing check decides.
        assertTrue(StorySplitView.resolveInSplit(reportedInSplit = null) { true })
        assertFalse(StorySplitView.resolveInSplit(reportedInSplit = null) { false })
    }

    @Test
    fun storyListLaunches_restartTheTaskOnlyFromEmbeddedScreens() {
        // A story list, reader, Discover, or the feed list slide-over opens the new list as a fresh task.
        assertTrue(StorySplitView.shouldRestartTaskForStoryList(rulesInstalled = true) { true })
        // Phones have no rules and never ask the embedding controller.
        assertFalse(
            StorySplitView.shouldRestartTaskForStoryList(rulesInstalled = false) {
                error("embedding checked on a phone")
            },
        )
        // A full screen activity that is not embedded launches directly.
        assertFalse(StorySplitView.shouldRestartTaskForStoryList(rulesInstalled = true) { false })
    }

    @Test
    fun rootStoryListsOnTablets_slideTheFeedListOver() {
        // A tablet's story list is the task root, with no feed list underneath, whatever its pane width.
        assertTrue(StorySplitView.shouldSlideOverFeedDrawer(rulesInstalled = true, isTaskRoot = true))
        // A list opened on top of Main.java, in a window too narrow to split, goes back to it.
        assertFalse(StorySplitView.shouldSlideOverFeedDrawer(rulesInstalled = true, isTaskRoot = false))
        // Phones keep going back to Main.java.
        assertFalse(StorySplitView.shouldSlideOverFeedDrawer(rulesInstalled = false, isTaskRoot = true))
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
        assertTrue(
            "StoryImageViewerHost must be declared so a photo tapped in a split can open full window",
            manifestActivityClasses().any { it.simpleName == "StoryImageViewerHost" },
        )
        assertTrue(
            "FeedListDrawer must be declared so the feed list can slide over a tablet's split",
            manifestActivityClasses().any { it.simpleName == "FeedListDrawer" },
        )
    }
}

// StorySplitViewTest.kt shares real pairing state with ReadingPreparedEntranceBackTest.kt so
// button visibility and Back eligibility are exercised independently of one another.
internal fun <T> withReaderSplitWindow(
    widthDp: Int,
    heightDp: Int = 800,
    pairedReader: Boolean = true,
    inSplit: Boolean = false,
    block: (Reading) -> T,
): T {
    val reading = mockk<Reading>(relaxed = true)
    val bounds = mockk<Rect>()
    every { bounds.width() } returns widthDp * 2
    every { bounds.height() } returns heightDp * 2
    every { reading.windowManager.currentWindowMetrics.bounds } returns bounds
    val displayMetrics = mockk<DisplayMetrics>().apply { density = 2f }
    every { reading.resources.displayMetrics } returns displayMetrics
    val configuration = mockk<Configuration>().apply {
        screenWidthDp = 360
        smallestScreenWidthDp = 360
    }
    every { reading.resources.configuration } returns configuration
    every { reading.isTaskRoot } returns false
    every { reading.isFinishing } returns false
    every { reading.isDestroyed } returns false

    fun field(name: String) = StorySplitView::class.java.getDeclaredField(name).apply { isAccessible = true }
    val rulesInstalled = field("rulesInstalled")
    val fullscreenSupported = field("readerFullscreenSupported")
    val originalRulesInstalled = rulesInstalled.getBoolean(null)
    val originalFullscreenSupported = fullscreenSupported.getBoolean(null)
    @Suppress("UNCHECKED_CAST")
    val pairing = field("reportedReaderPairing").get(null) as MutableMap<Activity, Boolean>
    @Suppress("UNCHECKED_CAST")
    val splitMembership = field("reportedSplitMembership").get(null) as MutableMap<Activity, Boolean>
    try {
        rulesInstalled.setBoolean(null, true)
        fullscreenSupported.setBoolean(null, true)
        pairing[reading] = pairedReader
        splitMembership[reading] = inSplit
        return block(reading)
    } finally {
        pairing.remove(reading)
        splitMembership.remove(reading)
        rulesInstalled.setBoolean(null, originalRulesInstalled)
        fullscreenSupported.setBoolean(null, originalFullscreenSupported)
    }
}
