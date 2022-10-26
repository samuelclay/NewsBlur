package com.newsblur.util

import com.newsblur.domain.Feed
import java.io.Serializable

/**
 * @return Set of folder keys that don't support
 * mark all read action
 */
private val invalidMarkAllReadFolderKeys by lazy {
    setOf(
            AppConstants.GLOBAL_SHARED_STORIES_GROUP_KEY,
            AppConstants.ALL_SHARED_STORIES_GROUP_KEY,
            AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
            AppConstants.READ_STORIES_GROUP_KEY,
            AppConstants.SAVED_STORIES_GROUP_KEY,
            AppConstants.SAVED_SEARCHES_GROUP_KEY,
    )
}

/**
 * As of writing this function, the zipping of the two sources
 * is valid as the "activeFolderNames" and "activeFolderChildren"
 * can be mapped by their folder name.
 * @return Map of folder names to their feed list.
 */
private fun List<String>.zipFolderFeed(foldersChildren: List<List<Feed>>): Map<String, List<Feed>> {
    val first = this.iterator()
    val second = foldersChildren.iterator()
    return buildMap {
        while (first.hasNext() && second.hasNext()) {
            this[first.next()] = second.next()
        }
    }
}

private fun Feed.toFeedSet() = FeedSet.singleFeed(this.feedId).apply {
    isMuted = !this@toFeedSet.active
}

/**
 * Represents the user's current reading session data source
 * as constructed and filtered by the home list adapter
 * based on settings and preferences.
 */
class SessionDataSource private constructor(
        private val folders: List<String>,
        private val foldersChildrenMap: Map<String, List<Feed>>
) : Serializable {

    private lateinit var session: Session

    constructor(
            activeSession: Session,
            folders: List<String>,
            foldersChildren: List<List<Feed>>,
    ) : this(
            folders = folders.filterNot { invalidMarkAllReadFolderKeys.contains(it) },
            foldersChildrenMap = folders.zipFolderFeed(foldersChildren)
                    .filterNot { invalidMarkAllReadFolderKeys.contains(it.key) },
    ) {
        this.session = activeSession
    }

    /**
     * @return The next feed within a folder or null if the folder
     * is showing the last feed.
     */
    private fun getNextFolderFeed(feed: Feed, folderName: String): Feed? {
        val cleanFolderName =
                // ROOT FOLDER maps to ALL_STORIES_GROUP_KEY
                if (folderName == AppConstants.ROOT_FOLDER)
                    AppConstants.ALL_STORIES_GROUP_KEY
                else folderName
        val folderFeeds = foldersChildrenMap[cleanFolderName]
        return folderFeeds?.let { feeds ->
            val feedIndex = feeds.indexOf(feed)
            if (feedIndex == -1) return null // invalid feed

            val nextFeedIndex = when (feedIndex) {
                feeds.size - 1 -> null // null feed if EOL
                in feeds.indices -> feedIndex + 1 // next feed
                else -> null // no valid feed found
            }

            nextFeedIndex?.let { feeds[it] }
        }
    }

    /**
     * @return The next non empty folder and its feeds based on the given folder name.
     * If the next folder doesn't have feeds, it will call itself with the new folder name
     * until it finds a non empty folder or it will get to the end of the folder list.
     */
    private fun getNextNonEmptyFolder(folderName: String): Pair<String, List<Feed>>? = with(folders.indexOf(folderName)) {
        val nextIndex = if (this == folders.size - 1) {
            0 // first folder if EOL
        } else if (this in folders.indices) {
            this + 1 // next folder
        } else this // no folder found

        val nextFolderName = if (nextIndex in folders.indices) {
            folders[nextIndex]
        } else null

        if (nextFolderName == null || nextFolderName == folderName)
            return null

        val feeds = foldersChildrenMap[nextFolderName]
        if (feeds == null || feeds.isEmpty())
        // try and get the next non empty folder name
            getNextNonEmptyFolder(nextFolderName)
        else nextFolderName to feeds
    }

    fun getNextSession(): Session? = if (session.feedSet.isFolder) {
        val folderName = session.feedSet.folderName
        getNextNonEmptyFolder(folderName)?.let { (nextFolderName, nextFolderFeeds) ->
            val nextFeedSet = FeedSet.folder(nextFolderName, nextFolderFeeds.map { it.feedId }.toSet())
            Session(feedSet = nextFeedSet, folderName = nextFolderName).also { nextSession ->
                session = nextSession
            }
        }
    } else if (session.feed != null && session.folderName != null) {
        val nextFeed = getNextFolderFeed(feed = session.feed!!, folderName = session.folderName!!)
        nextFeed?.let {
            Session(feedSet = it.toFeedSet(), session.folderName, it).also { nextSession ->
                session = nextSession
            }
        }
    } else null
}

/**
 * Represents the user's current reading session.
 *
 * When reading a folder, [folderName] and [feed] will be null.
 *
 * When reading a feed, [folderName] and [feed] will be non null.
 */
data class Session(
        val feedSet: FeedSet,
        val folderName: String? = null,
        val feed: Feed? = null,
) : Serializable

interface ReadingActionListener : Serializable {
    fun onReadingActionCompleted()
}