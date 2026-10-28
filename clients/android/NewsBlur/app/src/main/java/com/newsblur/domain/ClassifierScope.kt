package com.newsblur.domain

import com.google.gson.annotations.SerializedName
import java.io.Serializable

/**
 * Where a classifier applies, from the classifier payload's prompts_scope and image_prompts_scope
 * (apps/analyzer/models.py). A prompt that has no entry there is feed scoped.
 */
data class ClassifierScope(
    @JvmField
    @SerializedName("scope")
    val scope: String = FEED,
    // ClassifierScope.kt: the full folder path, such as "Blogs - Tumblrs", for folder scope.
    @JvmField
    @SerializedName("folder_name")
    val folderName: String = "",
) : Serializable {
    val isFeed: Boolean
        get() = scope != FOLDER && scope != GLOBAL

    companion object {
        private const val serialVersionUID = 1L

        const val FEED = "feed"
        const val FOLDER = "folder"
        const val GLOBAL = "global"

        @JvmField
        val FEED_SCOPE = ClassifierScope()

        @JvmStatic
        fun folder(folderName: String) = ClassifierScope(FOLDER, folderName)

        @JvmField
        val GLOBAL_SCOPE = ClassifierScope(GLOBAL)
    }
}

/**
 * One prompt change that /classifier/save has to receive at a folder or global scope, or a
 * feed-scoped removal after a prompt moved to a wider scope. Classifier.kt collects these
 * because that endpoint takes a single scope per request.
 */
data class ScopedPromptSave(
    @JvmField val scope: ClassifierScope = ClassifierScope.FEED_SCOPE,
    @JvmField val imagePrompt: Boolean = false,
    @JvmField val prompt: String = "",
    // Classifier.LIKE, DISLIKE, CLEAR_LIKE or CLEAR_DISLIKE.
    @JvmField val value: Int = Classifier.LIKE,
) : Serializable {
    companion object {
        private const val serialVersionUID = 1L
    }
}

/** The values for one extra /classifier/save request, see Classifier.getScopedPromptRequests. */
data class ScopedPromptRequest(
    val scope: ClassifierScope,
    val values: ValueMultimap,
)
