package com.newsblur.discover

import com.google.gson.JsonObject
import com.newsblur.network.APIConstants
import kotlin.math.roundToInt

// DescribeModels.kt mirrors the payloads of apps/describe/views.py: MDescribeSearch.summary(), to_payload() and
// DescribeUsageTracker.snapshot(). Parsing stays here, away from Compose, so Test_Describe.kt can cover it.

const val DESCRIBE_STATUS_QUEUED = "queued"
const val DESCRIBE_STATUS_RUNNING = "running"
const val DESCRIBE_STATUS_COMPLETE = "complete"
const val DESCRIBE_STATUS_ERROR = "error"
const val DESCRIBE_SOURCE_WEB = "web"

// DescribeModels.kt: pipeline phases in order, as apps/describe/pipeline.py reports them. The stepper shows them all.
enum class DescribePhase(
    val id: String,
) {
    EXPANDING("expanding"),
    SEARCHING("searching"),
    JUDGING("judging"),
    HUNTING("hunting"),
    COMPLETE("complete"),
    ;

    companion object {
        fun indexOf(phase: String): Int = entries.indexOfFirst { it.id == phase }
    }
}

data class DescribeSummary(
    val id: String,
    val prompt: String,
    val status: String,
    val phase: String,
    val createdDate: String,
    val completedDate: String,
    val resultCount: Int,
) {
    val running: Boolean get() = status == DESCRIBE_STATUS_QUEUED || status == DESCRIBE_STATUS_RUNNING
    val failed: Boolean get() = status == DESCRIBE_STATUS_ERROR

    companion object {
        fun parse(json: JsonObject): DescribeSummary? {
            val id = json.string("id")
            if (id.isBlank()) return null
            return DescribeSummary(
                id = id,
                prompt = json.string("prompt"),
                status = json.string("status"),
                phase = json.string("phase"),
                createdDate = json.string("created_date"),
                completedDate = json.string("completed_date"),
                resultCount = json.number("result_count"),
            )
        }
    }
}

data class DescribeResult(
    // DescribeModels.kt: the row key DescribeTab.kt uses for list keys. Use `feed.id` wherever a NewsBlur feed id is needed.
    val feedId: String,
    val feed: DiscoveryFeed,
    val source: String,
    val matchedQuery: String,
    val similarity: Double?,
    val score: Int?,
    val reason: String,
    val judged: Boolean,
) {
    val fromWeb: Boolean get() = source == DESCRIBE_SOURCE_WEB

    companion object {
        // DescribeModels.kt: a row is `make_result_row` plus the hydrated `feed` from `hydrate_results`.
        // A web find that is not saved yet has a negative `feed_id`: a row key for this search only, never a NewsBlur
        // feed id. Its `feed` has no `id` until the feed exists server-side, so DiscoveryViewModel.kt previews it through
        // /discover/link_popular_feed and subscribes by its address.
        fun parse(json: JsonObject): DescribeResult? {
            val rowKey =
                json
                    .string("feed_id")
                    .toDoubleOrNull()
                    ?.toLong()
                    ?.takeIf { it != 0L } ?: return null
            val feedId = rowKey.toString()
            val feed = DiscoveryFeed.parse(json) ?: return null
            // DescribeModels.kt: Feed.canonical() gives a site-relative favicon_url (/rss_feeds/icon/<id>), so make it absolute.
            val image = if (feed.image.startsWith("/")) APIConstants.buildUrl(feed.image) else feed.image
            return DescribeResult(
                feedId = feedId,
                feed = feed.copy(id = feed.id.ifBlank { if (rowKey > 0) feedId else "" }, image = image),
                source = json.string("source").ifBlank { "index" },
                matchedQuery = json.string("matched_query"),
                similarity = json.string("similarity").toDoubleOrNull(),
                score = json.string("score").toDoubleOrNull()?.roundToInt(),
                reason = json.string("reason"),
                judged = json.string("judged") == "true",
            )
        }
    }
}

data class DescribeSearch(
    val summary: DescribeSummary,
    val requestId: String,
    val phaseMessage: String,
    val subQueries: List<String>,
    val error: String,
    val note: String,
    val results: List<DescribeResult>,
) {
    val id: String get() = summary.id
    val prompt: String get() = summary.prompt
    val status: String get() = summary.status
    val phase: String get() = summary.phase
    val running: Boolean get() = summary.running
    val failed: Boolean get() = summary.failed
    val complete: Boolean get() = status == DESCRIBE_STATUS_COMPLETE

    companion object {
        fun parse(json: JsonObject): DescribeSearch? {
            val summary = DescribeSummary.parse(json) ?: return null
            val results = json.objects("results").mapNotNull(DescribeResult::parse)
            return DescribeSearch(
                summary = summary.copy(resultCount = results.size),
                requestId = json.string("request_id"),
                phaseMessage = json.string("phase_message"),
                subQueries = json.strings("sub_queries"),
                error = json.string("error"),
                note = json.obj("stats")?.string("note").orEmpty(),
                results = results,
            )
        }
    }
}

data class DescribeUsage(
    val tier: String,
    val limit: Int?,
    val used: Int,
    val remaining: Int?,
    val resetsIn: String,
) {
    // DescribeModels.kt: a zero limit means the plan has no Describe searches at all, so the tab shows the upgrade card.
    val locked: Boolean get() = limit == 0

    companion object {
        fun parse(json: JsonObject?): DescribeUsage? {
            json ?: return null
            return DescribeUsage(
                tier = json.string("tier"),
                limit = json.string("limit").toIntOrNull(),
                used = json.number("used"),
                remaining = json.string("remaining").toIntOrNull(),
                resetsIn = json.string("resets_in"),
            )
        }
    }
}

data class DescribeHistory(
    val searches: List<DescribeSummary>,
    val usage: DescribeUsage?,
)

// DescribeModels.kt: /discover/describe/start either starts a search or explains why it can't (quota or free plan).
sealed class DescribeStart {
    data class Started(
        val search: DescribeSearch,
        val usage: DescribeUsage?,
    ) : DescribeStart()

    data class Denied(
        val message: String,
        val upgrade: Boolean,
        val usage: DescribeUsage?,
    ) : DescribeStart()

    companion object {
        fun parse(json: JsonObject): DescribeStart {
            val usage = DescribeUsage.parse(json.obj("usage"))
            val search = json.obj("search")?.let(DescribeSearch::parse)
            return if (json.number("code") > 0 && search != null) {
                Started(search, usage)
            } else {
                Denied(json.string("message"), json.string("upgrade") == "true", usage)
            }
        }
    }
}

// DescribeModels.kt: server messages arrive already localized; the other cases map to string resources in DescribeTab.kt.
sealed class DescribeError {
    data class Message(
        val text: String,
    ) : DescribeError()

    data object StartFailed : DescribeError()

    data object LoadFailed : DescribeError()

    data object DeleteFailed : DescribeError()
}

data class DescribeState(
    val prompt: String = "",
    val search: DescribeSearch? = null,
    val history: List<DescribeSummary> = emptyList(),
    val historyLoaded: Boolean = false,
    val usage: DescribeUsage? = null,
    val starting: Boolean = false,
    val loading: Boolean = false,
    val error: DescribeError? = null,
    val upgradeMessage: String? = null,
) {
    val locked: Boolean get() = usage?.locked == true
    val showsUpgrade: Boolean get() = upgradeMessage != null || (locked && search == null && !loading)
}

internal fun JsonObject.strings(key: String): List<String> =
    get(key)
        ?.takeIf { it.isJsonArray }
        ?.asJsonArray
        ?.filter { it.isJsonPrimitive }
        ?.map { it.asString }
        .orEmpty()
