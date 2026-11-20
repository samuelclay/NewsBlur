package com.newsblur.domain

import com.google.gson.JsonParseException
import com.google.gson.annotations.SerializedName
import com.newsblur.database.DatabaseConstants
import java.io.Serializable

/**
 * One AI prompt classifier that matched a story, from the story API's prompt_classifiers list.
 * Story.java keeps these so ReadingItemFragment.kt can show why a story is focused or hidden,
 * the way media/js/newsblur/views/story_detail_view.js does on the web.
 */
data class PromptClassifierMatch(
    @JvmField
    @SerializedName("prompt")
    val prompt: String? = null,
    // 1 for a focus prompt that matched, -1 for a hidden prompt that matched.
    @JvmField
    @SerializedName("score")
    val score: Int = 0,
    // PromptClassifierMatch.kt: true for an Image Filter, false for a Content Filter.
    @JvmField
    @SerializedName("include_images")
    val includeImages: Boolean = false,
) : Serializable {
    val isFocus: Boolean
        get() = score > 0

    companion object {
        private const val serialVersionUID = 1L

        @JvmField
        val EMPTY: Array<PromptClassifierMatch> = emptyArray()

        /** Stories store their matches as one JSON text column, see DatabaseConstants.STORY_PROMPT_CLASSIFIERS. */
        @JvmStatic
        fun toJson(matches: Array<PromptClassifierMatch>?): String? =
            if (matches.isNullOrEmpty()) null else DatabaseConstants.JsonHelper.toJson(matches)

        @JvmStatic
        fun fromJson(json: String?): Array<PromptClassifierMatch> {
            if (json.isNullOrBlank()) return EMPTY
            return try {
                DatabaseConstants.JsonHelper
                    .fromJson(json, Array<PromptClassifierMatch>::class.java)
                    ?.filter { !it.prompt.isNullOrBlank() && it.score != 0 }
                    ?.toTypedArray()
                    ?: EMPTY
            } catch (_: JsonParseException) {
                EMPTY
            }
        }

        /** Drops nulls and empty prompts the API could send, so callers can render every entry. */
        @JvmStatic
        fun sanitize(matches: Array<PromptClassifierMatch?>?): Array<PromptClassifierMatch> =
            matches
                ?.filterNotNull()
                ?.filter { !it.prompt.isNullOrBlank() && it.score != 0 }
                ?.toTypedArray()
                ?: EMPTY
    }
}
