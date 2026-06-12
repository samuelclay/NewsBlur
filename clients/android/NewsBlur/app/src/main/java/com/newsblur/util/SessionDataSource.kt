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
        AppConstants.WIDELY_READ_STORIES_GROUP_KEY,
        AppConstants.LONG_READS_GROUP_KEY,
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

private fun Feed.toFeedSet() =
    FeedSet.singleFeed(this.feedId).apply {
        isMuted = !this@toFeedSet.active
    }

private fun cleanFolderName(folderName: String) =
    // ROOT FOLDER maps to ALL_STORIES_GROUP_KEY
    if (folderName == AppConstants.ROOT_FOLDER) {
        AppConstants.ALL_STORIES_GROUP_KEY
    } else {
        folderName
    }

/**
 * Represents the user's current reading session data source
 * as constructed and filtered by the home list adapter
 * based on settings and preferences.
 */
class SessionDataSource private constructor(
    folders: List<String>,
    foldersChildrenMap: Map<String, List<Feed>>,
    private val stateFilter: StateFilter?,
    savedFeedIds: Set<String>,
) : Serializable {
    private val folders: List<String> = folders.toList()
    private val foldersChildrenMap: Map<String, List<Feed>> = foldersChildrenMap.mapValues { it.value.toList() }.toMap()
    private val savedFeedIds: Set<String> = savedFeedIds.toSet()
    private lateinit var session: Session

    constructor(
        activeSession: Session,
        folders: List<String>,
        foldersChildren: List<List<Feed>>,
    ) : this(
        folders = folders.filterNot { invalidMarkAllReadFolderKeys.contains(it) },
        foldersChildrenMap =
            folders
                .zipFolderFeed(foldersChildren)
                .filterNot { invalidMarkAllReadFolderKeys.contains(it.key) },
        stateFilter = null,
        savedFeedIds = emptySet(),
    ) {
        this.session = activeSession
    }

    constructor(
        activeSession: Session,
        folders: List<String>,
        foldersChildren: List<List<Feed>>,
        stateFilter: StateFilter?,
        savedFeedIds: Set<String>,
    ) : this(
        folders = folders.filterNot { invalidMarkAllReadFolderKeys.contains(it) },
        foldersChildrenMap =
            folders
                .zipFolderFeed(foldersChildren)
                .filterNot { invalidMarkAllReadFolderKeys.contains(it.key) },
        stateFilter = stateFilter,
        savedFeedIds = savedFeedIds,
    ) {
        this.session = activeSession
    }

    /**
     * @return The next feed within a folder or null if the folder
     * is showing the last feed.
     */
    private fun getNextFolderFeed(
        feed: Feed,
        folderName: String,
    ): Feed? {
        val folderFeeds = foldersChildrenMap[folderName]
        return folderFeeds?.let { feeds ->
            val feedIndex = feeds.indexOf(feed)
            if (feedIndex == -1) return null // invalid feed

            if (stateFilter != null) {
                for (offset in 1..feeds.size) {
                    val nextFeedIndex = (feedIndex + offset) % feeds.size
                    val nextFeed = feeds[nextFeedIndex]
                    if (nextFeed == feed) continue
                    if (nextFeed.hasNextUnread()) return nextFeed
                }
                return null
            }

            val nextFeedIndex =
                when (feedIndex) {
                    feeds.size - 1 -> null // null feed if EOL
                    in feeds.indices -> feedIndex + 1 // next feed
                    else -> null // no valid feed found
                }

            nextFeedIndex?.let { feeds[it] }
        }
    }

    private fun findFolderNameContainingFeed(feed: Feed): String? =
        folders.firstOrNull { folderName ->
            foldersChildrenMap[folderName]?.contains(feed) == true
        }

    /**
     * @return The next non empty folder and its feeds based on the given folder name.
     * If the next folder doesn't have feeds, it will call itself with the new folder name
     * until it finds a non empty folder or it will get to the end of the folder list.
     */
    private fun getNextNonEmptyFolder(folderName: String): Pair<String, List<Feed>>? =
        with(folders.indexOf(folderName)) {
            val nextIndex =
                if (this == folders.size - 1) {
                    0 // first folder if EOL
                } else if (this in folders.indices) {
                    this + 1 // next folder
                } else {
                    this // no folder found
                }

            val nextFolderName =
                if (nextIndex in folders.indices) {
                    folders[nextIndex]
                } else {
                    null
                }

            if (nextFolderName == null || nextFolderName == folderName) {
                return null
            }

            val feeds = foldersChildrenMap[nextFolderName]
            if (feeds.isNullOrEmpty() || !feeds.hasNextUnreadTarget()) {
                // try and get the next non empty folder name
                getNextNonEmptyFolder(nextFolderName)
            } else {
                nextFolderName to feeds
            }
        }

    fun peekNextSession(): Session? =
        if (session.feedSet.isFolder) {
            val folderName = session.feedSet.folderName
            getNextNonEmptyFolder(folderName)?.let { (nextFolderName, nextFolderFeeds) ->
                val nextFeedSet = FeedSet.folder(nextFolderName, nextFolderFeeds.map { it.feedId }.toSet())
                Session(feedSet = nextFeedSet, folderName = nextFolderName)
            }
        } else if (session.feed != null && session.folderName != null) {
            val requestedFolderName = cleanFolderName(session.folderName!!)
            val folderName =
                if (foldersChildrenMap[requestedFolderName]?.contains(session.feed!!) == true) {
                    requestedFolderName
                } else {
                    findFolderNameContainingFeed(session.feed!!) ?: requestedFolderName
                }
            val nextFeed = getNextFolderFeed(feed = session.feed!!, folderName = folderName)
            nextFeed?.let {
                Session(feedSet = it.toFeedSet(), folderName, it)
            } ?: if (stateFilter != null) {
                getNextNonEmptyFolder(folderName)?.let { (nextFolderName, nextFolderFeeds) ->
                    val nextFeedSet = FeedSet.folder(nextFolderName, nextFolderFeeds.map { it.feedId }.toSet())
                    Session(feedSet = nextFeedSet, folderName = nextFolderName)
                }
            } else {
                null
            }
        } else {
            null
        }

    fun getNextSession(): Session? =
        peekNextSession()?.also { nextSession ->
            session = nextSession
        }

    fun setSession(session: Session) {
        this.session = session
    }

    private fun List<Feed>.hasNextUnreadTarget(): Boolean =
        if (stateFilter == null) {
            isNotEmpty()
        } else {
            any { it.hasNextUnread() }
        }

    private fun Feed.hasNextUnread(): Boolean =
        when (stateFilter) {
            StateFilter.ALL -> positiveCount + neutralCount + negativeCount > 0
            StateFilter.BEST -> positiveCount > 0
            StateFilter.SAVED -> savedFeedIds.contains(feedId)
            StateFilter.SOME, StateFilter.NEUT, StateFilter.NEG, null -> positiveCount + neutralCount > 0
        }
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
