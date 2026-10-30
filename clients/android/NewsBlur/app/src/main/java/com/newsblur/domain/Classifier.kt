package com.newsblur.domain

import android.content.ContentValues
import android.database.Cursor
import com.google.gson.annotations.SerializedName
import com.newsblur.database.DatabaseConstants
import java.io.Serializable

class Classifier : Serializable {
    // Classifier.kt keeps trainer order while avoiding Gson serialization hooks stripped by R8.
    @JvmField
    @SerializedName("authors")
    val authors: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("author_regex")
    val authorRegex: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("titles")
    val title: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("tags")
    val tags: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("feeds")
    val feeds: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("texts")
    val texts: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("text_regex")
    val textRegex: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("urls")
    val urls: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("url_regex")
    val urlRegex: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("title_regex")
    val titleRegex: LinkedHashMap<String, Int> = linkedMapOf()

    // Classifier.kt: AI prompt classifiers keyed by prompt text, LIKE for a focus prompt and DISLIKE
    // for a hidden one. Text prompts are Content Filters and image prompts are Image Filters.
    @JvmField
    @SerializedName("prompts")
    val prompts: LinkedHashMap<String, Int> = linkedMapOf()

    @JvmField
    @SerializedName("image_prompts")
    val imagePrompts: LinkedHashMap<String, Int> = linkedMapOf()

    // Folder and global prompts. A prompt missing from these maps is feed scoped.
    @JvmField
    @SerializedName("prompts_scope")
    val promptsScope: LinkedHashMap<String, ClassifierScope> = linkedMapOf()

    @JvmField
    @SerializedName("image_prompts_scope")
    val imagePromptsScope: LinkedHashMap<String, ClassifierScope> = linkedMapOf()

    // Folder and global titles, authors, tags, text and URLs, from apps/analyzer/models.py
    // get_classifiers_for_user. The server keys these by text for phrases and regexes alike, so a
    // regex shares its entry with a phrase of the same text. A classifier missing here is feed scoped.
    @JvmField
    @SerializedName("titles_scope")
    val titlesScope: LinkedHashMap<String, ClassifierScope> = linkedMapOf()

    @JvmField
    @SerializedName("authors_scope")
    val authorsScope: LinkedHashMap<String, ClassifierScope> = linkedMapOf()

    @JvmField
    @SerializedName("tags_scope")
    val tagsScope: LinkedHashMap<String, ClassifierScope> = linkedMapOf()

    @JvmField
    @SerializedName("texts_scope")
    val textsScope: LinkedHashMap<String, ClassifierScope> = linkedMapOf()

    @JvmField
    @SerializedName("urls_scope")
    val urlsScope: LinkedHashMap<String, ClassifierScope> = linkedMapOf()

    // Not vended by the API. The trainers (fragment/IntelTrainerSections.kt) fill this through
    // recordChanges with every classifier they changed, the only ones /classifier/save receives.
    @JvmField
    val changes: ArrayList<ClassifierChange> = arrayListOf()

    // there are scenarios where this is not vended by API; must be set manually
    @JvmField
    var feedId: String? = null

    fun hasStoryTextHighlights(): Boolean =
        texts.isNotEmpty() || textRegex.isNotEmpty()

    /** The scores of one classifier type, such as [TITLE] or [IMAGE_PROMPT]. */
    fun scores(type: Int): LinkedHashMap<String, Int> =
        when (type) {
            AUTHOR -> authors
            AUTHOR_REGEX -> authorRegex
            TITLE -> title
            TITLE_REGEX -> titleRegex
            TAG -> tags
            FEED -> feeds
            TEXT -> texts
            TEXT_REGEX -> textRegex
            URL -> urls
            URL_REGEX -> urlRegex
            PROMPT -> prompts
            IMAGE_PROMPT -> imagePrompts
            else -> throw IllegalArgumentException("Not a classifier type: $type")
        }

    // The publisher has no scope: apps/analyzer/views.py save_classifier always saves it per feed.
    private fun scopes(type: Int): LinkedHashMap<String, ClassifierScope>? =
        when (type) {
            AUTHOR, AUTHOR_REGEX -> authorsScope
            TITLE, TITLE_REGEX -> titlesScope
            TAG -> tagsScope
            TEXT, TEXT_REGEX -> textsScope
            URL, URL_REGEX -> urlsScope
            PROMPT -> promptsScope
            IMAGE_PROMPT -> imagePromptsScope
            else -> null
        }

    fun scope(
        type: Int,
        key: String,
    ): ClassifierScope = scopes(type)?.get(key) ?: ClassifierScope.FEED_SCOPE

    fun setScope(
        type: Int,
        key: String,
        scope: ClassifierScope,
    ) {
        // A feed outside every folder has no folder scope to move to, so its classifiers stay put.
        if (!scope.isValid) return
        val scopes = scopes(type) ?: return
        if (scope.isFeed) scopes.remove(key) else scopes[key] = scope
    }

    fun promptScope(
        imagePrompt: Boolean,
        prompt: String,
    ): ClassifierScope = scope(promptType(imagePrompt), prompt)

    fun setPromptScope(
        imagePrompt: Boolean,
        prompt: String,
        scope: ClassifierScope,
    ) = setScope(promptType(imagePrompt), prompt, scope)

    /** The feed-scoped /classifier/save request: the changes at feed scope, except removals waiting on a move. */
    fun getAPITuples(): ValueMultimap = tuples(changes.filter { it.scope.isFeed && it.movedTo == null })

    /** One /classifier/save request per folder or global scope with changes, sent after the feed save. */
    fun getScopedRequests(): List<ScopedClassifierRequest> = requests(changes.filter { !it.scope.isFeed && it.movedTo == null })

    /**
     * The removals at their old scope of classifiers that moved to one of [savedScopes], sent last
     * so a classifier whose new scope didn't save keeps its original instead of disappearing.
     */
    fun getMoveRemovalRequests(savedScopes: Set<ClassifierScope>): List<ScopedClassifierRequest> =
        requests(changes.filter { it.movedTo != null && it.movedTo in savedScopes })

    // A folder scope without its folder never goes out, see ClassifierScope.isValid.
    private fun requests(changes: List<ClassifierChange>): List<ScopedClassifierRequest> =
        changes
            .filter { it.scope.isValid }
            .groupBy { it.scope }
            .map { (scope, scopeChanges) -> ScopedClassifierRequest(scope, tuples(scopeChanges)) }

    private fun tuples(changes: List<ClassifierChange>): ValueMultimap {
        val values = ValueMultimap()
        changes.forEach { change -> tupleKey(change.type, change.value)?.let { values.put(it, change.key) } }
        return values
    }

    /** A copy of every score and scope, taken when a trainer opens, for recordChanges. */
    fun snapshot(): Classifier =
        Classifier().also { copy ->
            SAVED_TYPES.forEach { type -> copy.scores(type).putAll(scores(type)) }
            copy.promptsScope.putAll(promptsScope)
            copy.imagePromptsScope.putAll(imagePromptsScope)
            copy.titlesScope.putAll(titlesScope)
            copy.authorsScope.putAll(authorsScope)
            copy.tagsScope.putAll(tagsScope)
            copy.textsScope.putAll(textsScope)
            copy.urlsScope.putAll(urlsScope)
        }

    /**
     * Compares every classifier with the state the trainer opened with and lists what changed, so
     * an unchanged classifier is never sent again. A folder or global classifier is sent at its own
     * scope, never at feed scope, and a scope move lists both halves (the save at the new scope and
     * the removal at the old one), the way media/js/newsblur/reader/reader_classifier.js save()
     * collects scoped_saves.
     */
    fun recordChanges(original: Classifier) {
        changes.clear()
        SAVED_TYPES.forEach { type -> recordChanges(type, original) }
    }

    private fun recordChanges(
        type: Int,
        original: Classifier,
    ) {
        val originalScores = original.scores(type)
        for ((key, score) in scores(type)) {
            val scope = scope(type, key)
            // Nothing is sent for a classifier headed to an invalid scope, so its original survives.
            if (!scope.isValid) continue
            val originalScore = originalScores[key]
            val originalScope = if (originalScore == null) scope else original.scope(type, key)
            if (originalScope != scope) {
                // The old copy goes once the new one saves. A classifier that moved and lost its
                // opinion has no new copy, so its old one goes with the rest of the changes.
                if (isOpinion(originalScore)) {
                    val movedTo = if (isOpinion(score)) scope else null
                    changes.add(ClassifierChange(originalScope, type, key, clearValue(originalScore!!), movedTo))
                }
                if (isOpinion(score)) changes.add(ClassifierChange(scope, type, key, score))
            } else if (score != originalScore) {
                changes.add(ClassifierChange(scope, type, key, score))
            }
        }
    }

    private fun isOpinion(score: Int?): Boolean = score == LIKE || score == DISLIKE || score == SUPER_DISLIKE

    private fun clearValue(score: Int): Int =
        when (score) {
            SUPER_DISLIKE -> CLEAR_SUPER_DISLIKE
            DISLIKE -> CLEAR_DISLIKE
            else -> CLEAR_LIKE
        }

    private fun promptType(imagePrompt: Boolean): Int = if (imagePrompt) IMAGE_PROMPT else PROMPT

    private fun tupleKey(
        type: Int,
        value: Int,
    ): String? {
        val postfix =
            when (type) {
                AUTHOR -> AUTHOR_POSTFIX
                AUTHOR_REGEX -> AUTHOR_REGEX_POSTFIX
                TITLE -> TITLE_POSTFIX
                TITLE_REGEX -> TITLE_REGEX_POSTFIX
                TAG -> TAG_POSTFIX
                FEED -> FEED_POSTFIX
                TEXT -> TEXT_POSTFIX
                TEXT_REGEX -> TEXT_REGEX_POSTFIX
                URL -> URL_POSTFIX
                URL_REGEX -> URL_REGEX_POSTFIX
                PROMPT -> PROMPT_POSTFIX
                else -> IMAGE_PROMPT_POSTFIX
            }
        return if (type == PROMPT || type == IMAGE_PROMPT) buildPromptTupleKey(value, postfix) else buildAPITupleKey(value, postfix)
    }

    // Prompts have no super dislike, so apps/analyzer/views.py only accepts these four keys.
    private fun buildPromptTupleKey(
        action: Int,
        postfix: String,
    ): String? =
        when (action) {
            LIKE -> LIKE_PREFIX + postfix
            DISLIKE -> DISLIKE_PREFIX + postfix
            CLEAR_LIKE -> CLEAR_LIKE_PREFIX + postfix
            CLEAR_DISLIKE, CLEAR_SUPER_DISLIKE -> CLEAR_DISLIKE_PREFIX + postfix
            else -> null
        }

    private fun buildAPITupleKey(
        action: Int,
        postfix: String,
    ): String? =
        when (action) {
            LIKE -> LIKE_PREFIX + postfix
            DISLIKE -> DISLIKE_PREFIX + postfix
            SUPER_DISLIKE -> SUPER_DISLIKE_PREFIX + postfix
            CLEAR_LIKE -> CLEAR_LIKE_PREFIX + postfix
            CLEAR_DISLIKE -> CLEAR_DISLIKE_PREFIX + postfix
            CLEAR_SUPER_DISLIKE -> CLEAR_SUPER_DISLIKE_PREFIX + postfix
            else -> null
        }

    fun getContentValues(): List<ContentValues> {
        val valuesList = mutableListOf<ContentValues>()

        authors.forEach { (key, value) ->
            val authorValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, AUTHOR)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(authorValues)
        }

        authorRegex.forEach { (key, value) ->
            val regexValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, AUTHOR_REGEX)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(regexValues)
        }

        title.forEach { (key, value) ->
            val titleValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, TITLE)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(titleValues)
        }

        tags.forEach { (key, value) ->
            val tagValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, TAG)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(tagValues)
        }

        feeds.forEach { (key, value) ->
            val feedValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, FEED)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(feedValues)
        }

        texts.forEach { (key, value) ->
            val textValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, TEXT)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(textValues)
        }

        textRegex.forEach { (key, value) ->
            val regexValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, TEXT_REGEX)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(regexValues)
        }

        urls.forEach { (key, value) ->
            val urlValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, URL)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(urlValues)
        }

        urlRegex.forEach { (key, value) ->
            val regexValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, URL_REGEX)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(regexValues)
        }

        titleRegex.forEach { (key, value) ->
            val regexValues =
                ContentValues().apply {
                    put(DatabaseConstants.CLASSIFIER_ID, feedId)
                    put(DatabaseConstants.CLASSIFIER_KEY, key)
                    put(DatabaseConstants.CLASSIFIER_TYPE, TITLE_REGEX)
                    put(DatabaseConstants.CLASSIFIER_VALUE, value)
                }
            valuesList.add(regexValues)
        }

        prompts.forEach { (key, value) -> valuesList.add(promptContentValues(PROMPT, key, value.toString())) }
        imagePrompts.forEach { (key, value) -> valuesList.add(promptContentValues(IMAGE_PROMPT, key, value.toString())) }
        // Classifier.kt stores each prompt's scope as JSON in the value column.
        promptsScope.forEach { (key, scope) ->
            valuesList.add(promptContentValues(PROMPT_SCOPE, key, DatabaseConstants.JsonHelper.toJson(scope)))
        }
        imagePromptsScope.forEach { (key, scope) ->
            valuesList.add(promptContentValues(IMAGE_PROMPT_SCOPE, key, DatabaseConstants.JsonHelper.toJson(scope)))
        }
        // Classifier.kt stores the other classifiers' folder and global scopes the same way.
        STORED_SCOPES.forEach { (type, scopes) ->
            scopes(this).forEach { (key, scope) ->
                valuesList.add(promptContentValues(type, key, DatabaseConstants.JsonHelper.toJson(scope)))
            }
        }

        return valuesList
    }

    private fun promptContentValues(
        type: Int,
        key: String,
        value: String,
    ): ContentValues =
        ContentValues().apply {
            put(DatabaseConstants.CLASSIFIER_ID, feedId)
            put(DatabaseConstants.CLASSIFIER_KEY, key)
            put(DatabaseConstants.CLASSIFIER_TYPE, type)
            put(DatabaseConstants.CLASSIFIER_VALUE, value)
        }

    companion object {
        const val AUTHOR: Int = 0
        const val FEED: Int = 1
        const val TITLE: Int = 2
        const val TAG: Int = 3
        const val TEXT: Int = 4
        const val TEXT_REGEX: Int = 5
        const val URL: Int = 6
        const val URL_REGEX: Int = 7
        const val TITLE_REGEX: Int = 8
        const val AUTHOR_REGEX: Int = 9
        const val PROMPT: Int = 10
        const val IMAGE_PROMPT: Int = 11
        const val PROMPT_SCOPE: Int = 12
        const val IMAGE_PROMPT_SCOPE: Int = 13
        const val TITLE_SCOPE: Int = 14
        const val AUTHOR_SCOPE: Int = 15
        const val TAG_SCOPE: Int = 16
        const val TEXT_SCOPE: Int = 17
        const val URL_SCOPE: Int = 18

        /** Every type a trainer can change, in the order recordChanges lists them. */
        private val SAVED_TYPES =
            listOf(AUTHOR, AUTHOR_REGEX, TITLE, TITLE_REGEX, TAG, FEED, TEXT, TEXT_REGEX, URL, URL_REGEX, PROMPT, IMAGE_PROMPT)

        // The classifier table rows that hold folder and global scopes, by row type.
        private val STORED_SCOPES: Map<Int, (Classifier) -> LinkedHashMap<String, ClassifierScope>> =
            mapOf(
                TITLE_SCOPE to { it.titlesScope },
                AUTHOR_SCOPE to { it.authorsScope },
                TAG_SCOPE to { it.tagsScope },
                TEXT_SCOPE to { it.textsScope },
                URL_SCOPE to { it.urlsScope },
            )

        /** Whether apps/analyzer/views.py save_classifier can store [type] at a folder or global scope. */
        @JvmStatic
        fun canScope(type: Int): Boolean = type != FEED

        const val LIKE: Int = 1
        const val DISLIKE: Int = -1
        const val SUPER_DISLIKE: Int = -2
        const val CLEAR_DISLIKE: Int = 3
        const val CLEAR_LIKE: Int = 4
        const val CLEAR_SUPER_DISLIKE: Int = 5

        // API key postfix/prefix constants
        private const val AUTHOR_POSTFIX = "author"
        private const val AUTHOR_REGEX_POSTFIX = "author_regex"
        private const val FEED_POSTFIX = "feed"
        private const val TITLE_POSTFIX = "title"
        private const val TAG_POSTFIX = "tag"
        private const val TEXT_POSTFIX = "text"
        private const val URL_POSTFIX = "url"
        private const val TITLE_REGEX_POSTFIX = "title_regex"
        private const val TEXT_REGEX_POSTFIX = "text_regex"
        private const val URL_REGEX_POSTFIX = "url_regex"
        private const val PROMPT_POSTFIX = "prompt"
        private const val IMAGE_PROMPT_POSTFIX = "image_prompt"
        private const val LIKE_PREFIX = "like_"
        private const val DISLIKE_PREFIX = "dislike_"
        private const val SUPER_DISLIKE_PREFIX = "super_dislike_"
        private const val CLEAR_LIKE_PREFIX = "remove_like_"
        private const val CLEAR_DISLIKE_PREFIX = "remove_dislike_"
        private const val CLEAR_SUPER_DISLIKE_PREFIX = "remove_super_dislike_"

        @JvmStatic
        fun fromCursor(cursor: Cursor): Classifier {
            val classifier = Classifier()

            val keyIndex = cursor.getColumnIndexOrThrow(DatabaseConstants.CLASSIFIER_KEY)
            val valueIndex = cursor.getColumnIndexOrThrow(DatabaseConstants.CLASSIFIER_VALUE)
            val typeIndex = cursor.getColumnIndexOrThrow(DatabaseConstants.CLASSIFIER_TYPE)

            while (cursor.moveToNext()) {
                val key = cursor.getString(keyIndex)
                val type = cursor.getInt(typeIndex)
                if (type == PROMPT_SCOPE || type == IMAGE_PROMPT_SCOPE) {
                    val scope = DatabaseConstants.JsonHelper.fromJson(cursor.getString(valueIndex), ClassifierScope::class.java)
                    if (scope != null) {
                        if (type == PROMPT_SCOPE) classifier.promptsScope[key] = scope else classifier.imagePromptsScope[key] = scope
                    }
                    continue
                }
                val storedScopes = STORED_SCOPES[type]
                if (storedScopes != null) {
                    val scope = DatabaseConstants.JsonHelper.fromJson(cursor.getString(valueIndex), ClassifierScope::class.java)
                    if (scope != null) storedScopes(classifier)[key] = scope
                    continue
                }
                val value = cursor.getInt(valueIndex)

                when (type) {
                    AUTHOR -> classifier.authors[key] = value
                    AUTHOR_REGEX -> classifier.authorRegex[key] = value
                    TITLE -> classifier.title[key] = value
                    FEED -> classifier.feeds[key] = value
                    TAG -> classifier.tags[key] = value
                    TEXT -> classifier.texts[key] = value
                    TEXT_REGEX -> classifier.textRegex[key] = value
                    URL -> classifier.urls[key] = value
                    URL_REGEX -> classifier.urlRegex[key] = value
                    TITLE_REGEX -> classifier.titleRegex[key] = value
                    PROMPT -> classifier.prompts[key] = value
                    IMAGE_PROMPT -> classifier.imagePrompts[key] = value
                }
            }

            return classifier
        }
    }
}
