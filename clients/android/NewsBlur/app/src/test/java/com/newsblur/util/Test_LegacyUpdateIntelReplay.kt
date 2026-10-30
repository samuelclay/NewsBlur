package com.newsblur.util

import com.google.gson.Gson
import com.newsblur.domain.Classifier
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.APIResponse
import com.newsblur.network.FeedApiImpl
import com.newsblur.network.NetworkClient
import com.newsblur.network.domain.NewsBlurResponse
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URLDecoder

// Test_LegacyUpdateIntelReplay.kt: a trainer save the previous release (Android_16.1) left in the
// offline action queue still saves after the update. That release's Classifier.kt had no changes
// list and sent every score at feed scope, so its queued UpdateIntel replays the same request.
// A save queued by this release sends only what it recorded, nothing at all when nothing changed.
class Test_LegacyUpdateIntelReplay {
    private val networkClient = mockk<NetworkClient>()
    private val feedApi = FeedApiImpl(Gson(), networkClient)
    private val bodies = mutableListOf<List<String>>()

    init {
        coEvery { networkClient.post(any(), any<ValueMultimap>()) } answers {
            bodies += fields(secondArg())
            val response = mockk<APIResponse>()
            every { response.getResponse(any(), NewsBlurResponse::class.java) } returns NewsBlurResponse()
            response
        }
    }

    // ReadingAction.kt's Gson output for an UpdateIntel in Android_16.1, whose Classifier.kt had
    // only these ten score maps and feedId. Its trainer could clear a score, like the dislike on
    // "Daring Fireball Department of Commerce" here.
    private val previousReleaseJson =
        """
        {"type":"UPDATE_INTEL","feedId":"42","classifier":{
          "authors":{"John Gruber":1,"Daring Fireball Department of Commerce":3},
          "author_regex":{"^Sponsor":-1},
          "titles":{"[Sponsor]":-2},
          "tags":{"tech":1},
          "feeds":{"42":1},
          "texts":{"WorkOS":-1},
          "text_regex":{"sponsor(ed)?":-1},
          "urls":{"/linked/":1},
          "url_regex":{"/\\d{4}/":1},
          "title_regex":{"\\bApple\\b":1},
          "feedId":"42"},
        "feedSet":{"feeds":["42"],"isAllRead":false,"isGlobalShared":false,"isInfrequent":false,"isDailyBriefing":false,
          "isForWidget":false,"isFilterSaved":false,"muted":false},
        "time":1761700000000,"tried":0}
        """.trimIndent()

    private val apiPayload =
        """
        {"authors": {"John Gruber": 1}, "titles": {"[Sponsor]": -2}, "feeds": {"42": 1}}
        """.trimIndent()

    private suspend fun replay(json: String) {
        val action = ReadingAction.fromJson(json) as ReadingAction.UpdateIntel
        feedApi.updateFeedIntel(action.feedId, action.classifier)
    }

    /** Queues [classifier] the way FeedUtils.updateClassifier does and reads it back. */
    private fun queued(classifier: Classifier): String =
        ReadingAction.toJson(ReadingAction.UpdateIntel("42", classifier, FeedSet.singleFeed("42")))

    @Test
    fun test_a_save_queued_by_the_previous_release_sends_what_it_sent() =
        runTest {
            replay(previousReleaseJson)

            assertEquals(
                "Every author, author regex, title, tag, site, text and URL score, and no other regexes",
                listOf(
                    listOf(
                        "dislike_author_regex=^Sponsor",
                        "dislike_text=WorkOS",
                        "feed_id=42",
                        "like_author=John Gruber",
                        "like_feed=42",
                        "like_tag=tech",
                        "like_url=/linked/",
                        "remove_dislike_author=Daring Fireball Department of Commerce",
                        "super_dislike_title=[Sponsor]",
                    ),
                ),
                bodies,
            )
        }

    @Test
    fun test_a_new_save_with_no_changes_sends_no_classifiers() =
        runTest {
            val classifier = Gson().fromJson(apiPayload, Classifier::class.java)
            classifier.recordChanges(classifier.snapshot())
            val json = queued(classifier)

            replay(json)

            assertTrue(json, "\"changes_recorded\":true" in json)
            assertEquals(listOf(listOf("feed_id=42")), bodies)
        }

    @Test
    fun test_a_new_save_sends_only_its_changes_after_the_queue() =
        runTest {
            val classifier = Gson().fromJson(apiPayload, Classifier::class.java)
            val original = classifier.snapshot()
            classifier.tags["apple"] = Classifier.LIKE
            classifier.recordChanges(original)

            replay(queued(classifier))

            assertEquals(listOf(listOf("feed_id=42", "like_tag=apple")), bodies)
        }

    // The form fields of one request, decoded and sorted since ValueMultimap.java keeps no order.
    private fun fields(values: ValueMultimap): List<String> {
        val body = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()
        return body.split("&").map { URLDecoder.decode(it, "UTF-8") }.sorted()
    }
}
