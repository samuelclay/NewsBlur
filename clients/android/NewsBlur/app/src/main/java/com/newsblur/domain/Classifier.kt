package com.newsblur.domain

import android.content.ContentValues
import android.database.Cursor
import com.google.gson.annotations.SerializedName
import com.newsblur.database.DatabaseConstants
import java.io.Serializable

class Classifier : Serializable {
    @JvmField
    @SerializedName("authors")
    val authors: MutableMap<String, Int> = mutableMapOf()

    @JvmField
    @SerializedName("titles")
    val title: MutableMap<String, Int> = mutableMapOf()

    @JvmField
    @SerializedName("tags")
    val tags: MutableMap<String, Int> = mutableMapOf()

    @JvmField
    @SerializedName("feeds")
    val feeds: MutableMap<String, Int> = mutableMapOf()

    // there are scenarios where this is not vended by API; must be set manually
    @JvmField
    var feedId: String? = null

    fun getAPITuples(): ValueMultimap {
        val values = ValueMultimap()

        authors.forEach { (key, value) ->
            buildAPITupleKey(value, AUTHOR_POSTFIX)?.let { values.put(it, key) }
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

        return values
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

        return valuesList
    }

    companion object {
        const val AUTHOR: Int = 0
        const val FEED: Int = 1
        const val TITLE: Int = 2
        const val TAG: Int = 3

        const val LIKE: Int = 1
        const val DISLIKE: Int = -1
        const val SUPER_DISLIKE: Int = -2
        const val CLEAR_DISLIKE: Int = 3
        const val CLEAR_LIKE: Int = 4
        const val CLEAR_SUPER_DISLIKE: Int = 5

        // API key postfix/prefix constants
        private const val AUTHOR_POSTFIX = "author"
        private const val FEED_POSTFIX = "feed"
        private const val TITLE_POSTFIX = "title"
        private const val TAG_POSTFIX = "tag"
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
                val value = cursor.getInt(valueIndex)

                when (cursor.getInt(typeIndex)) {
                    AUTHOR -> classifier.authors[key] = value
                    TITLE -> classifier.title[key] = value
                    FEED -> classifier.feeds[key] = value
                    TAG -> classifier.tags[key] = value
                }
            }

            return classifier
        }
    }
}
