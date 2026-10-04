package com.newsblur.onboarding

import com.newsblur.discover.DiscoveryFeed
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Test

class SetupOpmlTest {
    @Test fun mixedNewsBlurExportKeepsOrdinaryAndInternalFeeds() {
        val xml = """<opml><body><outline text="News"><outline text="RSS" xmlUrl="https://a.test/rss"/><outline text="Newsletter" xmlUrl="newsletter:123:inbox"/><outline text="Web feed" xmlUrl="webfeed:456"/></outline></body></opml>"""
        val result = SetupOpml.parse(xml.toByteArray())
        assertEquals(
            listOf("https://a.test/rss", "newsletter:123:inbox", "webfeed:456"),
            result["News"]!!.map { it.url },
        )
        listOf("file:///etc/passwd", "javascript:alert(1)", "data:text/plain,feed").forEach { url ->
            val unsafe = xml.replace("webfeed:456", url)
            assertTrue(runCatching { SetupOpml.parse(unsafe.toByteArray()) }.isFailure)
        }
    }

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

    @Test fun boundsFileSizeAndUnnamedNestingBeforeImport() {
        val oversized = ByteArray(SetupOpml.MAX_BYTES + 1)
        assertTrue(runCatching { SetupOpml.read(oversized.inputStream()) }.isFailure)
        val deep = "<opml><body>" + "<outline>".repeat(130) +
            "<outline xmlUrl='https://a.test/rss'/>" + "</outline>".repeat(130) + "</body></opml>"
        assertTrue(runCatching { SetupOpml.parse(deep.toByteArray()) }.isFailure)
        val external = "<!DOCTYPE opml [<!ENTITY secret SYSTEM 'file:///etc/passwd'>]><opml><body>&secret;</body></opml>"
        assertTrue(runCatching { SetupOpml.parse(external.toByteArray(Charsets.UTF_16)) }.isFailure)
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
