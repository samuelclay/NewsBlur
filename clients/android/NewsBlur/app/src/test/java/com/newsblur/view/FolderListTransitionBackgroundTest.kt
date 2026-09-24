package com.newsblur.view

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import com.newsblur.R
import com.newsblur.util.UIUtils
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import io.mockk.verifyOrder
import java.lang.reflect.InvocationTargetException
import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class FolderListTransitionBackgroundTest {
    @Test
    fun fadingRowsAreDrawnOverTheFolderSurfaceInsideTheViewportClip() {
        val fixture = fixture(animating = true)
        try {
            fixture.draw()

            verifyOrder {
                fixture.canvas.clipRect(4, 8, 596, 792)
                fixture.background.setBounds(4, 8, 596, 792)
                fixture.background.draw(fixture.canvas)
            }
        } finally {
            unmockkStatic(UIUtils::class)
        }
    }

    @Test
    fun theTransitionSurfaceDoesNotChangeTheRestingEmptyListBackground() {
        val fixture = fixture(animating = false)
        try {
            fixture.draw()
            verify(exactly = 0) { fixture.background.draw(any()) }
        } finally {
            unmockkStatic(UIUtils::class)
        }
    }

    @Test
    fun everyThemeResolvesTheExistingOpaqueFolderSurface() {
        val themes = document("values/theme.xml")
        val styles = document("values/styles.xml")
        val colors = document("values/colors.xml")
        val palette = listOf(
            "NewsBlurTheme" to "feed_list_row_background",
            "NewsBlurSepiaTheme" to "folder_background_sepia",
            "NewsBlurDarkTheme" to "dark_folder_background",
            "NewsBlurBlackTheme" to "black_folder_background",
        )
        for ((theme, expectedColor) in palette) {
            val themeStyle = elements(themes, "style").single { it.getAttribute("name") == theme }
            val styleName = elements(themeStyle, "item").single { it.getAttribute("name") == "selectorFolderBackground" }
                .textContent.removePrefix("@style/")
            val rowStyle = elements(styles, "style").single { it.getAttribute("name") == styleName }
            val selectorName = elements(rowStyle, "item").single { it.getAttribute("name") == "android:background" }
                .textContent.removePrefix("@drawable/")
            val selector = document("drawable-nodpi/$selectorName.xml")
            val defaultItem = elements(selector, "item").single { it.attributes.length == 1 }
            val surfaceName = defaultItem.getAttribute("android:drawable").removePrefix("@drawable/")
            val surface = document("drawable-nodpi/$surfaceName.xml")
            assertEquals(
                "$theme must share row_folder.xml's normal surface",
                "@color/$expectedColor",
                elements(surface, "solid").single().getAttribute("android:color"),
            )
            val color = elements(colors, "color").single { it.getAttribute("name") == expectedColor }.textContent
            assertTrue(
                "$theme must not reveal the window through the transition floor",
                color.matches(Regex("#[0-9a-fA-F]{6}|#[fF]{2}[0-9a-fA-F]{6}")),
            )
        }
    }

    private fun fixture(animating: Boolean): Fixture {
        val view = mockk<AnimatedFolderListView>(relaxed = true)
        val canvas = mockk<Canvas>(relaxed = true)
        val context = mockk<Context>(relaxed = true)
        val background = mockk<Drawable>(relaxed = true)
        mockkStatic(UIUtils::class)
        every { UIUtils.getThemedResource(context, R.attr.selectorFolderBackground, android.R.attr.background) } returns 123
        every { context.getDrawable(123) } returns background
        every { background.mutate() } returns background
        every { view.context } returns context
        every { view.paddingLeft } returns 4
        every { view.paddingRight } returns 4
        every { view.paddingTop } returns 8
        every { view.paddingBottom } returns 8
        every { view.width } returns 600
        every { view.height } returns 800
        every { view["dispatchDraw"](canvas) } answers { callOriginal() }
        AnimatedFolderListView::class.java.getDeclaredField("leavingRows").apply { isAccessible = true }.set(view, emptyList<Any>())
        AnimatedFolderListView::class.java.getDeclaredField("animator").apply { isAccessible = true }
            .set(view, if (animating) mockk<ValueAnimator>() else null)
        return Fixture(view, canvas, background)
    }

    private data class Fixture(
        val view: AnimatedFolderListView,
        val canvas: Canvas,
        val background: Drawable,
    ) {
        fun draw() {
            try {
                AnimatedFolderListView::class.java.getDeclaredMethod("dispatchDraw", Canvas::class.java)
                    .apply { isAccessible = true }.invoke(view, canvas)
            } catch (exception: InvocationTargetException) {
                // AnimatedFolderListView.kt's real overlay drawing runs before Android's JVM stub.
                // Only stop at that platform boundary; application errors must still fail this test.
                if (exception.cause?.message?.startsWith("Method dispatchDraw in android.widget.ExpandableListView not mocked.") != true) {
                    throw exception
                }
            }
        }
    }

    private fun document(path: String) =
        Files.newInputStream(Paths.get("src/main/res/$path")).use {
            DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(it).documentElement
        }

    private fun elements(parent: Element, tag: String): List<Element> {
        val nodes = parent.getElementsByTagName(tag)
        return (0 until nodes.length).map { nodes.item(it) as Element }
    }
}
