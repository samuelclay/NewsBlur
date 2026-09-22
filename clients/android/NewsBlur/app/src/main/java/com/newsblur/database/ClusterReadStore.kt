package com.newsblur.database

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import com.google.gson.Gson
import com.newsblur.domain.Story
import com.newsblur.util.FeedSet
import com.newsblur.util.ReadingAction

/** ClusterReadStore.kt uses an indexed reverse lookup instead of scanning story JSON during scrolling. */
class ClusterReadStore(private val db: SQLiteDatabase) : ClusterReadRepository.Backend {
    private val gson = Gson()

    @JvmOverloads
    fun apply(hashes: Collection<String>, read: Boolean, adjustCounts: Boolean, actionTime: Long? = null): Set<FeedSet> =
        ClusterReadRepository(this).apply(hashes, read, adjustCounts, actionTime)

    fun applyBulkRead(selection: String?, actionTime: Long) {
        val hashes = mutableListOf<String>()
        db.query(DatabaseConstants.STORY_TABLE, arrayOf("story_hash"), selection, null, null, null, null).use {
            while (it.moveToNext()) hashes.add(it.getString(0))
        }
        ClusterReadRepository(this).applyBulkRead(hashes, actionTime)
    }

    fun normalizeStory(story: Story, readStatusAuthoritative: Boolean) {
        // A full story response acknowledges an override; embedded metadata alone cannot revoke it.
        val local = localReadState(story.storyHash)
        if (local != null) {
            if (readStatusAuthoritative && local == story.read) db.delete(READ_STATE, "story_hash = ?", arrayOf(story.storyHash))
            else story.read = local
        } else if (!readStatusAuthoritative) {
            val stored = storedStory(story.storyHash)
            if (stored != null) {
                story.read = stored.read
            } else {
                // ReaderTargetLoader.kt can fetch a child known only through an indexed parent cluster.
                // Hash responses use an unread placeholder, so preserve any matching known read copy.
                val knownRead = parentsReferencing(setOf(story.storyHash)).values.any { children ->
                    children.any { it.storyHash == story.storyHash && it.read }
                }
                if (knownRead) story.read = true
            }
        }
        story.clusterStories = (story.clusterStories ?: emptyArray()).map { child ->
            val read = localReadState(child.storyHash) ?: storedStory(child.storyHash)?.read?.takeIf { it }
            if (read != null && read != child.read) ClusterReadRepository.copyWithReadState(child, read) else child
        }.toTypedArray()
    }

    fun registerStory(story: Story) = registerClusters(story.storyHash, story.clusterStories ?: emptyArray())

    fun reconcileServerUnread(hashes: Collection<String>, requestStartedAt: Long) {
        val candidates = mutableSetOf<String>()
        val embeddedCandidates = mutableSetOf<String>()
        for (chunk in hashes.chunked(400)) {
            val params = chunk.joinToString(",") { "?" }
            db.rawQuery("SELECT story_hash FROM ${DatabaseConstants.STORY_TABLE} WHERE read = 1 AND story_hash IN ($params) " +
                "UNION SELECT story_hash FROM $READ_STATE WHERE read = 1 AND story_hash IN ($params)",
                (chunk + chunk).toTypedArray()).use { while (it.moveToNext()) candidates.add(it.getString(0)) }
            db.rawQuery("SELECT DISTINCT child_hash FROM $MEMBERS WHERE child_hash IN ($params)",
                chunk.toTypedArray()).use { while (it.moveToNext()) embeddedCandidates.add(it.getString(0)) }
        }
        // ClusterReadStore.kt also respects remote unread changes for children not yet stored individually.
        // Only indexed, known-read children need a receipt; the rest of the server unread list stays untouched.
        for (children in parentsReferencing(embeddedCandidates).values) {
            for (child in children) {
                if (child.read && child.storyHash in embeddedCandidates) candidates.add(child.storyHash)
            }
        }
        reconcileServerReadState(candidates, false, requestStartedAt)
    }

    fun reconcileServerReadState(hashes: Collection<String>, read: Boolean, requestStartedAt: Long) {
        ClusterReadRepository(this).reconcileServerReadState(hashes, read, requestStartedAt)
    }

    fun cleanup() {
        db.execSQL("DELETE FROM $READ_STATE WHERE story_hash NOT IN (SELECT story_hash FROM ${DatabaseConstants.STORY_TABLE}) " +
            "AND story_hash NOT IN (SELECT child_hash FROM $MEMBERS)")
    }

    private fun registerClusters(parentHash: String, children: Array<Story.ClusterStory>) {
        db.delete(MEMBERS, "parent_hash = ?", arrayOf(parentHash))
        for (child in children) {
            if (child.storyHash.isNullOrBlank()) continue
            db.insertWithOnConflict(MEMBERS, null, ContentValues().apply {
                put("parent_hash", parentHash)
                put("child_hash", child.storyHash)
            }, SQLiteDatabase.CONFLICT_IGNORE)
        }
    }

    override fun storedStory(hash: String): ClusterReadRepository.State? =
        db.query(DatabaseConstants.STORY_TABLE, arrayOf(DatabaseConstants.STORY_FEED_ID,
            DatabaseConstants.STORY_INTELLIGENCE_TOTAL, DatabaseConstants.STORY_READ,
            DatabaseConstants.STORY_SOCIAL_USER_ID, DatabaseConstants.STORY_FRIEND_USER_IDS),
            "story_hash = ?", arrayOf(hash), null, null, null).use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val social = mutableSetOf<String>()
            cursor.getString(3)?.takeIf { it.isNotBlank() }?.let(social::add)
            cursor.getString(4)?.takeIf { it.isNotBlank() }?.let {
                social.addAll(it.split(',').filter(String::isNotBlank))
            }
            ClusterReadRepository.State(cursor.getString(0), cursor.getInt(1), cursor.getInt(2) != 0, social)
        }

    override fun localReadState(hash: String): Boolean? =
        db.query(READ_STATE, arrayOf("read"), "story_hash = ?", arrayOf(hash), null, null, null).use {
            if (it.moveToFirst()) it.getInt(0) != 0 else null
        }

    override fun localReadChangedAt(hash: String): Long? =
        db.query(READ_STATE, arrayOf("updated_at"), "story_hash = ?", arrayOf(hash), null, null, null).use {
            if (it.moveToFirst()) it.getLong(0) else null
        }

    override fun pendingReadStateHashes(): Set<String> {
        val hashes = mutableSetOf<String>()
        var pendingBulkRead = false
        db.query(DatabaseConstants.ACTION_TABLE, arrayOf(DatabaseConstants.ACTION_PARAMS), null, null, null, null, null).use {
            while (it.moveToNext()) {
                val action = try {
                    ReadingAction.fromJson(it.getString(0))
                } catch (_: IllegalArgumentException) {
                    continue
                } catch (_: com.google.gson.JsonParseException) {
                    continue
                }
                when (action) {
                    is ReadingAction.MarkStoryRead -> {
                        hashes.add(action.storyHash)
                        hashes.addAll(action.relatedStoryHashes.orEmpty())
                    }
                    is ReadingAction.MarkStoryUnread -> hashes.add(action.storyHash)
                    is ReadingAction.MarkFeedRead -> pendingBulkRead = true
                    else -> Unit
                }
            }
        }
        // ReadingAction.kt replays pending bulk intents after sync; preserve their local receipts until then.
        if (pendingBulkRead) db.query(READ_STATE, arrayOf("story_hash"), null, null, null, null, null).use {
            while (it.moveToNext()) hashes.add(it.getString(0))
        }
        return hashes
    }

    override fun parentsReferencing(hashes: Set<String>): Map<String, Array<Story.ClusterStory>> {
        val parents = linkedMapOf<String, Array<Story.ClusterStory>>()
        // Small chunks also respect SQLite's bind parameter limit for very large server clusters.
        for (chunk in hashes.chunked(400)) {
            val params = chunk.joinToString(",") { "?" }
            db.rawQuery("SELECT DISTINCT s.story_hash, s.cluster_stories FROM $MEMBERS m " +
                "JOIN ${DatabaseConstants.STORY_TABLE} s ON s.story_hash = m.parent_hash " +
                "WHERE m.child_hash IN ($params)", chunk.toTypedArray()).use { cursor ->
                while (cursor.moveToNext()) parents[cursor.getString(0)] = decode(cursor.getString(1))
            }
        }
        return parents
    }

    override fun setLocalReadState(hash: String, read: Boolean, changedAt: Long) {
        db.insertWithOnConflict(READ_STATE, null, ContentValues().apply {
            put("story_hash", hash)
            put("read", read)
            put("updated_at", changedAt)
        }, SQLiteDatabase.CONFLICT_REPLACE)
    }

    override fun setStoredReadState(hash: String, read: Boolean) {
        db.update(DatabaseConstants.STORY_TABLE, ContentValues().apply { put(DatabaseConstants.STORY_READ, read) },
            "story_hash = ?", arrayOf(hash))
    }

    override fun setParentClusters(hash: String, children: Array<Story.ClusterStory>) {
        db.update(DatabaseConstants.STORY_TABLE, ContentValues().apply {
            put(DatabaseConstants.STORY_CLUSTER_STORIES, gson.toJson(children))
        }, "story_hash = ?", arrayOf(hash))
    }

    override fun adjustCounts(state: ClusterReadRepository.State, delta: Int) {
        val column = if (state.score > 0) DatabaseConstants.FEED_POSITIVE_COUNT else DatabaseConstants.FEED_NEUTRAL_COUNT
        db.execSQL("UPDATE ${DatabaseConstants.FEED_TABLE} SET $column = MAX(0, $column + ?) WHERE ${DatabaseConstants.FEED_ID} = ?",
            arrayOf(delta, state.feedId))
        val socialColumn = if (state.score > 0) DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT else DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT
        for (socialId in state.socialIds) db.execSQL("UPDATE ${DatabaseConstants.SOCIALFEED_TABLE} SET $socialColumn = MAX(0, $socialColumn + ?) " +
            "WHERE ${DatabaseConstants.SOCIAL_FEED_ID} = ?", arrayOf(delta, socialId))
    }

    private fun decode(json: String?): Array<Story.ClusterStory> =
        if (json.isNullOrBlank()) emptyArray() else gson.fromJson(json, Array<Story.ClusterStory>::class.java) ?: emptyArray()

    companion object {
        const val MEMBERS = "story_cluster_members"
        const val READ_STATE = "story_cluster_read_state"

        @JvmStatic fun createTables(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE $MEMBERS (parent_hash TEXT NOT NULL, child_hash TEXT NOT NULL, PRIMARY KEY(parent_hash, child_hash))")
            db.execSQL("CREATE INDEX story_cluster_child ON $MEMBERS(child_hash)")
            db.execSQL("CREATE TABLE $READ_STATE (story_hash TEXT PRIMARY KEY NOT NULL, read INTEGER NOT NULL, updated_at INTEGER NOT NULL)")
            // BlurDatabaseHelper.java deletes cached stories through several paths; the trigger covers all of them.
            db.execSQL("CREATE TRIGGER story_cluster_cleanup AFTER DELETE ON ${DatabaseConstants.STORY_TABLE} BEGIN " +
                "DELETE FROM $MEMBERS WHERE parent_hash = OLD.story_hash; END")
        }

        @JvmStatic fun backfill(db: SQLiteDatabase) {
            val store = ClusterReadStore(db)
            db.query(DatabaseConstants.STORY_TABLE, arrayOf("story_hash", "cluster_stories"),
                "cluster_stories IS NOT NULL AND cluster_stories != '[]'", null, null, null, null).use {
                while (it.moveToNext()) store.registerClusters(it.getString(0), store.decode(it.getString(1)))
            }
        }

        @JvmStatic fun dropTables(db: SQLiteDatabase) {
            db.execSQL("DROP TRIGGER IF EXISTS story_cluster_cleanup")
            db.execSQL("DROP TABLE IF EXISTS $MEMBERS")
            db.execSQL("DROP TABLE IF EXISTS $READ_STATE")
        }
    }
}
