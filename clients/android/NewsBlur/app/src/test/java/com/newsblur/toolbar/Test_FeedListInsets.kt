package com.newsblur.toolbar

import org.junit.Assert.assertEquals
import org.junit.Test
import org.w3c.dom.Element
import java.nio.file.Files
import java.nio.file.Paths
import javax.xml.parsers.DocumentBuilderFactory

@Suppress("ktlint:standard:class-naming")
class Test_FeedListInsets {
    @Test
    fun test_fragment_inflation_preserves_feed_list_id_for_toolbar_insets() {
        val main = document("activity_main.xml")
        val list = document("fragment_folderfeedlist.xml")
        val fragments = main.getElementsByTagName("fragment")
        val feedList =
            (0 until fragments.length)
                .map { fragments.item(it) as Element }
                .single { it.getAttribute("android:name") == "com.newsblur.fragment.FolderListFragment" }

        // Test_FeedListInsets.kt: FragmentLayoutInflaterFactory replaces the root view ID with the fragment tag's ID,
        // including NO_ID when omitted. Main.java cannot reserve toolbar space if folderfeed_list is lost.
        assertEquals(
            "The static fragment must preserve the list ID used by Main.java's floating toolbar inset",
            list.getAttribute("android:id"),
            feedList.getAttribute("android:id"),
        )
    }

    private fun document(name: String) =
        Files.newInputStream(Paths.get("src/main/res/layout/$name")).use {
            DocumentBuilderFactory
                .newInstance()
                .newDocumentBuilder()
                .parse(it)
                .documentElement
        }
}
