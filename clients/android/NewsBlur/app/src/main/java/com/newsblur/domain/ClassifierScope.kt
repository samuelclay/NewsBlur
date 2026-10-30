package com.newsblur.domain

import com.google.gson.annotations.SerializedName
import java.io.Serializable

/**
 * Where a classifier applies, from the classifier payload's prompts_scope, titles_scope and the
 * other *_scope maps (apps/analyzer/models.py). A classifier that has no entry there is feed scoped.
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

    /**
     * apps/analyzer/views.py saves a folder scope without a folder name as feed_id=0 and
     * folder_id="", which is a global prompt that runs, and bills, on every site.
     */
    val isValid: Boolean
        get() = scope != FOLDER || folderName.isNotBlank()

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
 * One classifier change for /classifier/save, recorded by Classifier.recordChanges: a score at a
 * scope, or the removal at its old scope of a classifier that moved. Classifier.kt collects these
 * because that endpoint takes a single scope per request.
 */
data class ClassifierChange(
    @JvmField val scope: ClassifierScope = ClassifierScope.FEED_SCOPE,
    // Classifier.TITLE, AUTHOR_REGEX, PROMPT and the like.
    @JvmField val type: Int = Classifier.TITLE,
    @JvmField val key: String = "",
    // Classifier.LIKE, DISLIKE, SUPER_DISLIKE or one of the CLEAR values.
    @JvmField val value: Int = Classifier.LIKE,
    // ClassifierScope.kt: the scope a classifier moved to, set on the removal at its old scope.
    // FeedApiImpl.kt sends that removal only once the new scope saved.
    @JvmField val movedTo: ClassifierScope? = null,
) : Serializable {
    companion object {
        private const val serialVersionUID = 1L
    }
}

/** The values for one extra /classifier/save request, see Classifier.getScopedRequests. */
data class ScopedClassifierRequest(
    val scope: ClassifierScope,
    val values: ValueMultimap,
)
