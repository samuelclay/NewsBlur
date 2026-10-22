package com.newsblur.listen

import com.google.gson.JsonObject
import com.google.gson.annotations.SerializedName

/**
 * ListenModels.kt mirrors the Listen endpoints' JSON contract shared by the web, iOS and Android clients.
 * Every field has a default so Gson can build these through the generated no-argument constructor.
 */
data class ListenVoice(
    @SerializedName("voice_id") val voiceId: String = "",
    @SerializedName("name") val name: String = "",
    @SerializedName("description") val description: String? = null,
    @SerializedName("gender") val gender: String? = null,
    @SerializedName("age") val age: String? = null,
    @SerializedName("accent") val accent: String? = null,
    @SerializedName("use_case") val useCase: String? = null,
    @SerializedName("descriptive") val descriptive: String? = null,
    @SerializedName("language") val language: String? = null,
    @SerializedName("locale") val locale: String? = null,
    @SerializedName("preview_url") val previewUrl: String? = null,
    @SerializedName("category") val category: String? = null,
    @SerializedName("source") val source: String? = null,
)

data class ListenUsage(
    @SerializedName("tier") val tier: String? = null,
    @SerializedName("is_archive_tier") val isArchiveTier: Boolean = false,
    @SerializedName("seconds_used") val secondsUsed: Double = 0.0,
    @SerializedName("seconds_limit") val secondsLimit: Double? = null,
    @SerializedName("seconds_remaining") val secondsRemaining: Double? = null,
    @SerializedName("resets_at") val resetsAt: String? = null,
    @SerializedName("samples_used") val samplesUsed: Int = 0,
    @SerializedName("samples_limit") val samplesLimit: Int? = null,
    @SerializedName("preview_seconds") val previewSeconds: Double? = null,
    @SerializedName("previews_used") val previewsUsed: Int = 0,
    @SerializedName("previews_limit") val previewsLimit: Int? = null,
    @SerializedName("upgrade_message") val upgradeMessage: String? = null,
)

data class ListenParagraph(
    @SerializedName("index") val index: Int = 0,
    @SerializedName("kind") val kind: String? = null,
    @SerializedName("text") val text: String? = null,
) {
    val isTitle: Boolean
        get() = kind == KIND_TITLE

    companion object {
        const val KIND_TITLE = "title"
    }
}

data class ListenSegment(
    @SerializedName("index") val index: Int = 0,
    @SerializedName("paragraphs") val paragraphs: List<Int> = emptyList(),
    @SerializedName("characters") val characters: Int = 0,
    @SerializedName("duration") val duration: Double = 0.0,
    @SerializedName("estimated") val estimated: Boolean = true,
    @SerializedName("cached") val cached: Boolean = false,
)

data class ListenPreviewInfo(
    @SerializedName("is_preview") val isPreview: Boolean = false,
    @SerializedName("seconds") val seconds: Double = 30.0,
    @SerializedName("samples_used") val samplesUsed: Int = 0,
    @SerializedName("samples_limit") val samplesLimit: Int? = null,
)

data class ListenManifest(
    @SerializedName("code") val code: Int = 0,
    @SerializedName("reason") val reason: String? = null,
    @SerializedName("message") val message: String? = null,
    @SerializedName("manifest_id") val manifestId: String = "",
    @SerializedName("expires_at") val expiresAt: Double = 0.0,
    @SerializedName("story_hash") val storyHash: String = "",
    @SerializedName("feed_id") val feedId: String? = null,
    @SerializedName("story_title") val storyTitle: String? = null,
    @SerializedName("feed_title") val feedTitle: String? = null,
    @SerializedName("language") val language: String? = null,
    @SerializedName("detected_language") val detectedLanguage: String? = null,
    @SerializedName("voice") val voice: ListenVoice? = null,
    @SerializedName("voice_fallback") val voiceFallback: Boolean = false,
    @SerializedName("text_source") val textSource: String? = null,
    @SerializedName("paragraphs") val paragraphs: List<ListenParagraph> = emptyList(),
    @SerializedName("segments") val segments: List<ListenSegment> = emptyList(),
    @SerializedName("total_duration") val totalDuration: Double = 0.0,
    @SerializedName("preview") val preview: ListenPreviewInfo? = null,
    @SerializedName("usage") val usage: ListenUsage? = null,
) {
    val isPreview: Boolean
        get() = preview?.isPreview == true
}

data class ListenSegmentResponse(
    @SerializedName("code") val code: Int = 0,
    @SerializedName("reason") val reason: String? = null,
    @SerializedName("message") val message: String? = null,
    @SerializedName("index") val index: Int = 0,
    @SerializedName("url") val url: String? = null,
    @SerializedName("cached") val cached: Boolean = false,
    @SerializedName("duration") val duration: Double? = null,
    @SerializedName("characters") val characters: Int = 0,
    @SerializedName("usage") val usage: ListenUsage? = null,
)

data class ListenLanguage(
    @SerializedName("code") val code: String = "",
    @SerializedName("name") val name: String = "",
)

data class ListenDeliveryPreset(
    @SerializedName("id") val id: String = "",
    @SerializedName("stability") val stability: Double = 0.5,
    @SerializedName("similarity") val similarity: Double = 0.75,
    @SerializedName("style") val style: Double = 0.0,
)

data class ListenFilterOption(
    @SerializedName("value") val value: String = "",
    @SerializedName("label") val label: String? = null,
)

data class ListenVoicesResponse(
    @SerializedName("code") val code: Int = 0,
    @SerializedName("reason") val reason: String? = null,
    @SerializedName("message") val message: String? = null,
    @SerializedName("languages") val languages: List<ListenLanguage> = emptyList(),
    @SerializedName("voices") val voices: Map<String, List<ListenVoice>> = emptyMap(),
    @SerializedName("defaults") val defaults: Map<String, String> = emptyMap(),
    @SerializedName("selected") val selected: Map<String, String> = emptyMap(),
    @SerializedName("delivery_presets") val deliveryPresets: List<ListenDeliveryPreset> =
        emptyList(),
    // ListenModels.kt reads filters by hand (ListenFilters.parse) because "accent" is a per-language map
    // of raw strings while every other filter is a list of value and label pairs.
    @SerializedName("filters") val filters: JsonObject? = null,
    @SerializedName("usage") val usage: ListenUsage? = null,
)

/** ListenModels.kt: the library filters offered by GET /listen/voices, ready for the voice browser. */
data class ListenFilters(
    val options: Map<String, List<ListenFilterOption>> = emptyMap(),
    val accents: Map<String, List<String>> = emptyMap(),
) {
    fun accentsFor(language: String): List<String> = accents[language].orEmpty()

    companion object {
        const val KEY_GENDER = "gender"
        const val KEY_AGE = "age"
        const val KEY_ACCENT = "accent"
        const val KEY_USE_CASE = "use_case"
        const val KEY_DESCRIPTIVE = "descriptive"
        const val KEY_SORT = "sort"

        fun parse(json: JsonObject?): ListenFilters {
            if (json == null) return ListenFilters()
            val options = linkedMapOf<String, List<ListenFilterOption>>()
            val accents = linkedMapOf<String, List<String>>()
            for ((key, element) in json.entrySet()) {
                when {
                    element.isJsonArray ->
                        options[key] =
                            element.asJsonArray.mapNotNull { option ->
                                when {
                                    option.isJsonObject -> {
                                        val item = option.asJsonObject
                                        val value =
                                            item
                                                .get("value")
                                                ?.takeIf {
                                                    it.isJsonPrimitive
                                                }?.asString
                                        val label =
                                            item
                                                .get("label")
                                                ?.takeIf {
                                                    it.isJsonPrimitive
                                                }?.asString
                                        value?.let { ListenFilterOption(it, label) }
                                    }
                                    option.isJsonPrimitive ->
                                        ListenFilterOption(
                                            option.asString,
                                            null,
                                        )
                                    else -> null
                                }
                            }
                    key == KEY_ACCENT && element.isJsonObject ->
                        for ((language, values) in element.asJsonObject.entrySet()) {
                            if (values.isJsonArray) {
                                accents[language] =
                                    values.asJsonArray
                                        .filter {
                                            it.isJsonPrimitive
                                        }.map { it.asString }
                            }
                        }
                }
            }
            return ListenFilters(options, accents)
        }

        /** Accents arrive as raw ElevenLabs strings like "american" or "us-southern"; show them title-cased. */
        fun displayAccent(raw: String): String =
            raw
                .split(' ', '_', '-')
                .filter { it.isNotBlank() }
                .joinToString(" ") { word -> word.replaceFirstChar { it.titlecase() } }
    }
}

data class ListenLibraryResponse(
    @SerializedName("code") val code: Int = 0,
    @SerializedName("reason") val reason: String? = null,
    @SerializedName("message") val message: String? = null,
    @SerializedName("voices") val voices: List<ListenVoice> = emptyList(),
    @SerializedName("has_more") val hasMore: Boolean = false,
    @SerializedName("page") val page: Int = 0,
)

data class ListenVoicePreviewResponse(
    @SerializedName("code") val code: Int = 0,
    @SerializedName("reason") val reason: String? = null,
    @SerializedName("message") val message: String? = null,
    @SerializedName("url") val url: String? = null,
    @SerializedName("text") val text: String? = null,
    @SerializedName("voice") val voice: ListenVoice? = null,
    @SerializedName("cached") val cached: Boolean = false,
    /** True when the url is the voice's own hosted sample clip, so nothing was generated or counted. */
    @SerializedName("sample") val sample: Boolean = false,
    @SerializedName("usage") val usage: ListenUsage? = null,
)

data class ListenUsageResponse(
    @SerializedName("code") val code: Int = 0,
    @SerializedName("reason") val reason: String? = null,
    @SerializedName("message") val message: String? = null,
    @SerializedName("usage") val usage: ListenUsage? = null,
)

/** POST /listen/progress only answers whether it took the report. */
data class ListenProgressResponse(
    @SerializedName("code") val code: Int = 0,
    @SerializedName("reason") val reason: String? = null,
    @SerializedName("message") val message: String? = null,
)

/** ListenModels.kt keeps the server's machine reason for logic and its localized message for people. */
data class ListenError(
    val reason: String?,
    val message: String?,
    val usage: ListenUsage? = null,
) {
    val isUpgradeReason: Boolean
        get() =
            reason == REASON_SAMPLE_LIMIT ||
                reason == REASON_CAP_REACHED ||
                reason == REASON_PREVIEW_ENDED

    companion object {
        const val REASON_SAMPLE_LIMIT = "sample_limit"
        const val REASON_CAP_REACHED = "cap_reached"
        const val REASON_NOT_FOUND = "not_found"
        const val REASON_NO_TEXT = "no_text"
        const val REASON_UNAVAILABLE = "unavailable"
        const val REASON_MANIFEST_EXPIRED = "manifest_expired"
        const val REASON_PREVIEW_ENDED = "preview_ended"
        const val REASON_BAD_INDEX = "bad_index"
        const val REASON_PREVIEW_LIMIT = "preview_limit"

        // Busy servers: manifests may answer rate_limited and segments busy; both show their message with Retry.
        const val REASON_RATE_LIMITED = "rate_limited"
        const val REASON_BUSY = "busy"

        /** No response arrived, so ListenManager.kt shows its own localized network message. */
        const val REASON_NETWORK = "network"

        /** Media3 could not play the audio it was given. */
        const val REASON_PLAYBACK = "playback"
    }
}

sealed interface ListenResult<out T> {
    data class Success<T>(
        val value: T,
    ) : ListenResult<T>

    data class Failure(
        val error: ListenError,
    ) : ListenResult<Nothing>
}
