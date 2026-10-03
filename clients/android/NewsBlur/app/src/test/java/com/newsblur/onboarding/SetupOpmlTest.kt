package com.newsblur.onboarding

import com.newsblur.discover.DiscoveryFeed
import org.junit.Assert.*
import org.junit.Test

class SetupOpmlTest {
    @Test fun nestedFoldersAndDuplicateFeedsKeepTheirPaths() {
        val xml = """<opml><body><outline text="News"><outline text="Local"><outline text="A" xmlUrl="https://a.test/rss"/><outline text="A again" xmlUrl="https://a.test/rss"/></outline></outline><outline text="Root" xmlUrl="https://root.test/rss"/></body></opml>"""
        val result = SetupOpml.parse(xml.toByteArray())
        assertEquals(setOf("News ▸ Local", ""), result.keys)
        assertEquals(1, result["News ▸ Local"]!!.size)
    }

    @Test fun rejectsExternalEntitiesAndEmptyFiles() {
        listOf(
            "",
            "<opml><body/></opml>",
            "<rss/>",
            "<!DOCTYPE opml [<!ENTITY secret SYSTEM 'file:///etc/passwd'>]><opml><body>&secret;</body></opml>",
        ).forEach { xml ->
            assertTrue(runCatching { SetupOpml.parse(xml.toByteArray()) }.isFailure)
        }
    }

    @Test fun progressiveSourcesDoNotResetUserChoices() {
        val a = DiscoveryFeed("https://a", "A")
        val b = DiscoveryFeed("https://b", "B")
        val c = DiscoveryFeed("https://c", "C")
        val choices = BundleChoices().append(listOf(a, b), setOf(b.url)).toggle(a.url).append(listOf(a, b, c), setOf(b.url))
        assertEquals(listOf(a, b, c), choices.feeds)
        assertEquals(setOf(c.url), choices.selected)
    }
}

class Test_OnboardingGate {
    @Test fun emptyAccountResponsesAcceptBothServerShapesButNeverMissingOrUnauthenticatedData() {
        fun empty(json: String) =
            hasEmptySubscriptions(
                com.google.gson.JsonParser
                    .parseString(json)
                    .asJsonObject,
            )
        assertTrue(empty("""{"authenticated":true,"feeds":[]}"""))
        assertTrue(empty("""{"authenticated":true,"feeds":{}}"""))
        assertFalse(empty("""{"authenticated":true,"feeds":{"1":{}}}"""))
        assertFalse(empty("""{"authenticated":true}"""))
        assertFalse(empty("""{"authenticated":false,"feeds":[]}"""))
    }
}
