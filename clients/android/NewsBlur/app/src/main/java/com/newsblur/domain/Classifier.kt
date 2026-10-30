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

    // Not vended by the API. StoryIntelTrainerFragment.java fills this through
    // recordScopedPromptChanges with the prompt changes that need their own scoped request.
    @JvmField
    val scopedPromptSaves: ArrayList<ScopedPromptSave> = arrayListOf()

    // Not vended by the API. The trainers fill this through recordRegexChanges with the title,
    // text and URL regexes the reader changed, the only ones getAPITuples sends.
    @JvmField
    val changedRegexes: ArrayList<RegexChange> = arrayListOf()

    // there are scenarios where this is not vended by API; must be set manually
    @JvmField
    var feedId: String? = null

    fun hasStoryTextHighlights(): Boolean =
        texts.isNotEmpty() || textRegex.isNotEmpty()

    fun getAPITuples(): ValueMultimap {
        val values = ValueMultimap()

        authors.forEach { (key, value) ->
            buildAPITupleKey(value, AUTHOR_POSTFIX)?.let { values.put(it, key) }
        }
        authorRegex.forEach { (key, value) ->
            buildAPITupleKey(value, AUTHOR_REGEX_POSTFIX)?.let { values.put(it, key) }
        }
        title.forEach { (key, value) ->
            buildAPITupleKey(value, TITLE_POSTFIX)?.let { values.put(it, key) }
        }
        tags.forEach { (key, value) ->
            buildAPITupleKey(value, TAG_POSTFIX)?.let { values.put(it, key) }
        }
        feeds.forEach { (key, value) ->
            buildAPITupleKey(value, FEED_POSTFIX)?.let { values.put(it, key) }
        }
        texts.forEach { (key, value) ->
            buildAPITupleKey(value, TEXT_POSTFIX)?.let { values.put(it, key) }
        }
        urls.forEach { (key, value) ->
            buildAPITupleKey(value, URL_POSTFIX)?.let { values.put(it, key) }
        }
        // Title, text and URL regexes were never sent back unchanged, so only the trainer's
        // changes to them go out, see recordRegexChanges.
        changedRegexes.forEach { change ->
            val (scores, postfix) =
                when (change.type) {
                    TITLE_REGEX -> titleRegex to TITLE_REGEX_POSTFIX
                    TEXT_REGEX -> textRegex to TEXT_REGEX_POSTFIX
                    else -> urlRegex to URL_REGEX_POSTFIX
                }
            scores[change.pattern]?.let { value -> buildAPITupleKey(value, postfix)?.let { values.put(it, change.pattern) } }
        }
        // Folder and global prompts go out through getScopedPromptRequests instead. Sending them
        // here, at feed scope, would create a feed copy that runs (and bills) alongside the original.
        prompts.forEach { (key, value) ->
            if (key !in promptsScope) buildPromptTupleKey(value, PROMPT_POSTFIX)?.let { values.put(it, key) }
        }
        imagePrompts.forEach { (key, value) ->
            if (key !in imagePromptsScope) buildPromptTupleKey(value, IMAGE_PROMPT_POSTFIX)?.let { values.put(it, key) }
        }
        // A moved prompt's feed copy waits for getMoveRemovalRequests, after its new scope saves.
        scopedPromptSaves.filter { it.scope.isFeed && it.movedTo == null }.forEach { save ->
            buildPromptTupleKey(save.value, promptPostfix(save.imagePrompt))?.let { values.put(it, save.prompt) }
        }

        return values
    }

    /** One /classifier/save request per folder or global scope with prompt changes, sent after the feed save. */
    fun getScopedPromptRequests(): List<ScopedPromptRequest> =
        promptRequests(scopedPromptSaves.filter { !it.scope.isFeed && it.movedTo == null })

    /**
     * The removals at their old scope of prompts that moved to one of [savedScopes], sent last so
     * a prompt whose new scope didn't save keeps its original instead of disappearing.
     */
    fun getMoveRemovalRequests(savedScopes: Set<ClassifierScope>): List<ScopedPromptRequest> =
        promptRequests(scopedPromptSaves.filter { it.movedTo != null && it.movedTo in savedScopes })

    // A folder scope without its folder never goes out, see ClassifierScope.isValid.
    private fun promptRequests(saves: List<ScopedPromptSave>): List<ScopedPromptRequest> =
        saves
            .filter { it.scope.isValid }
            .groupBy { it.scope }
            .map { (scope, scopeSaves) ->
                val values = ValueMultimap()
                scopeSaves.forEach { save ->
                    buildPromptTupleKey(save.value, promptPostfix(save.imagePrompt))?.let { values.put(it, save.prompt) }
                }
                ScopedPromptRequest(scope, values)
            }

    /** A copy of the prompt state, taken when a trainer opens, for recordScopedPromptChanges. */
    fun copyPrompts(): Classifier =
        Classifier().also { copy ->
            copy.prompts.putAll(prompts)
            copy.imagePrompts.putAll(imagePrompts)
            copy.promptsScope.putAll(promptsScope)
            copy.imagePromptsScope.putAll(imagePromptsScope)
        }

    /** A copy of the title, text and URL regexes, taken when a trainer opens, for recordRegexChanges. */
    fun copyRegexes(): Classifier =
        Classifier().also { copy ->
            copy.titleRegex.putAll(titleRegex)
            copy.textRegex.putAll(textRegex)
            copy.urlRegex.putAll(urlRegex)
        }

    /** Lists the title, text and URL regexes whose score differs from the state the trainer opened with. */
    fun recordRegexChanges(original: Classifier) {
        changedRegexes.clear()
        recordRegexChanges(TITLE_REGEX, original.titleRegex, titleRegex)
        recordRegexChanges(TEXT_REGEX, original.textRegex, textRegex)
        recordRegexChanges(URL_REGEX, original.urlRegex, urlRegex)
    }

    private fun recordRegexChanges(
        type: Int,
        originalScores: Map<String, Int>,
        scores: Map<String, Int>,
    ) {
        scores.forEach { (pattern, score) ->
            if (originalScores[pattern] != score) changedRegexes.add(RegexChange(type, pattern))
        }
    }

    fun promptScope(
        imagePrompt: Boolean,
        prompt: String,
    ): ClassifierScope = (if (imagePrompt) imagePromptsScope else promptsScope)[prompt] ?: ClassifierScope.FEED_SCOPE

    fun setPromptScope(
        imagePrompt: Boolean,
        prompt: String,
        scope: ClassifierScope,
    ) {
        // A feed outside every folder has no folder scope to move to, so its prompts stay put.
        if (!scope.isValid) return
        val scopes = if (imagePrompt) imagePromptsScope else promptsScope
        if (scope.isFeed) scopes.remove(prompt) else scopes[prompt] = scope
    }

    /**
     * Compares the prompts with the state the trainer opened with and lists the changes that
     * getAPITuples can't send at feed scope: edits to folder and global prompts, and both halves
     * of a scope move (the removal at the old scope and the save at the new one), the same way
     * media/js/newsblur/reader/reader_classifier.js save() collects scoped_saves.
     */
    fun recordScopedPromptChanges(original: Classifier) {
        scopedPromptSaves.clear()
        recordScopedPromptChanges(false, original.prompts, original.promptsScope, prompts, promptsScope)
        recordScopedPromptChanges(true, original.imagePrompts, original.imagePromptsScope, imagePrompts, imagePromptsScope)
    }

    private fun recordScopedPromptChanges(
        imagePrompt: Boolean,
        originalScores: Map<String, Int>,
        originalScopes: Map<String, ClassifierScope>,
        scores: Map<String, Int>,
        scopes: Map<String, ClassifierScope>,
    ) {
        for (prompt in scores.keys) {
            val score = scores.getValue(prompt)
            val scope = scopes[prompt] ?: ClassifierScope.FEED_SCOPE
            // Nothing is sent for a prompt headed to an invalid scope, so its original survives.
            if (!scope.isValid) continue
            val originalScore = originalScores[prompt]
            val originalScope = if (originalScore == null) scope else originalScopes[prompt] ?: ClassifierScope.FEED_SCOPE
            val active = score == LIKE || score == DISLIKE
            if (originalScope != scope) {
                // The old copy goes once the new one saves. A prompt that moved and was removed
                // has no new copy, so its old one goes with the rest of the changes.
                if (originalScore == LIKE || originalScore == DISLIKE) {
                    val movedTo = if (active) scope else null
                    scopedPromptSaves.add(ScopedPromptSave(originalScope, imagePrompt, prompt, clearValue(originalScore), movedTo))
                }
                if (!scope.isFeed && active) scopedPromptSaves.add(ScopedPromptSave(scope, imagePrompt, prompt, score))
            } else if (!scope.isFeed && score != originalScore) {
                scopedPromptSaves.add(ScopedPromptSave(scope, imagePrompt, prompt, score))
            }
        }
    }

    private fun clearValue(score: Int): Int = if (score == DISLIKE) CLEAR_DISLIKE else CLEAR_LIKE

    private fun promptPostfix(imagePrompt: Boolean): String = if (imagePrompt) IMAGE_PROMPT_POSTFIX else PROMPT_POSTFIX

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
