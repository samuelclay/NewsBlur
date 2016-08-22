package com.newsblur.database;

import android.content.ContentValues;
import android.content.Context;
import android.content.Loader;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.AsyncTask;
import android.os.CancellationSignal;
import android.text.TextUtils;
import android.util.Log;

import com.newsblur.domain.Classifier;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.domain.Reply;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.StarredCount;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadingAction;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;

import java.util.Arrays;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collection;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Utility class for executing DB operations on the local, private NB database.
 *
 * It is the intent of this class to be the single location of SQL executed on
 * our DB, replacing the deprecated ContentProvider access pattern.
 */
public class BlurDatabaseHelper {

    // manual synchro isn't needed if you only use one DBHelper, but at present the app uses several
    public final static Object RW_MUTEX = new Object();

    private Context context;
    private final BlurDatabase dbWrapper;
    private SQLiteDatabase dbRO;
    private SQLiteDatabase dbRW;

    public BlurDatabaseHelper(Context context) {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "new DB conn requested");
        this.context = context;
        synchronized (RW_MUTEX) {
            dbWrapper = new BlurDatabase(context);
            dbRO = dbWrapper.getRO();
            dbRW = dbWrapper.getRW();
        }
    }

    public void close() {
        // when asked to close, do so via an AsyncTask. This is so that (since becoming serial in android 4.0) 
        // the closure will happen after other async tasks are done using the conn
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                synchronized (RW_MUTEX) {dbWrapper.close();}
                return null;
            }
        }.execute();
    }

    public void dropAndRecreateTables() {
        synchronized (RW_MUTEX) {dbWrapper.dropAndRecreateTables();}
    }

    public String getEngineVersion() {
        String engineVersion = "";
        try {
            Cursor c = dbRO.rawQuery("SELECT sqlite_version() AS sqlite_version", null);
            if (c.moveToFirst()) {
                engineVersion = c.getString(0);
            }
            c.close();
        } catch (Exception e) {
            // this is only debug code, do not rais a failure
        }
        return engineVersion;
    }

    public Set<String> getAllFeeds() {
        String q1 = "SELECT " + DatabaseConstants.FEED_ID +
                    " FROM " + DatabaseConstants.FEED_TABLE;
        Cursor c = dbRO.rawQuery(q1, null);
        LinkedHashSet<String> feedIds = new LinkedHashSet<String>(c.getCount());
        while (c.moveToNext()) {
           feedIds.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.FEED_ID)));
        }
        c.close();
        return feedIds;
    }

    private List<String> getAllSocialFeeds() {
        String q1 = "SELECT " + DatabaseConstants.SOCIAL_FEED_ID +
                    " FROM " + DatabaseConstants.SOCIALFEED_TABLE;
        Cursor c = dbRO.rawQuery(q1, null);
        List<String> feedIds = new ArrayList<String>(c.getCount());
        while (c.moveToNext()) {
           feedIds.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.SOCIAL_FEED_ID)));
        }
        c.close();
        return feedIds;
    }

    /**
     * Clean up stories from more than a month ago. This is the oldest an unread can be,
     * and a good cutoff point for what it is sane for us to store for users that ask
     * us to keep a copy of read stories.  This is necessary primarily to catch any
     * stories that get missed by cleanupReadStories() because their read state might
     * not have been correctly resolved and they get orphaned in the DB.
     */
    public void cleanupVeryOldStories() {
        Calendar cutoffDate = Calendar.getInstance();
        cutoffDate.add(Calendar.MONTH, -1);
        synchronized (RW_MUTEX) {
            int count = dbRW.delete(DatabaseConstants.STORY_TABLE, 
                        DatabaseConstants.STORY_TIMESTAMP + " < ?" +
                        " AND " + DatabaseConstants.STORY_TEXT_STORY_HASH + " NOT IN " +
                        "( SELECT " + DatabaseConstants.READING_SESSION_STORY_HASH + " FROM " + DatabaseConstants.READING_SESSION_TABLE + ")",
                        new String[]{Long.toString(cutoffDate.getTime().getTime())});
        }
    }

    /**
     * Clean up stories that have already been read, unless they are being actively
     * displayed to the user.
     */
    public void cleanupReadStories() {
        synchronized (RW_MUTEX) {
            int count = dbRW.delete(DatabaseConstants.STORY_TABLE, 
                        DatabaseConstants.STORY_READ + " = 1" +
                        " AND " + DatabaseConstants.STORY_TEXT_STORY_HASH + " NOT IN " +
                        "( SELECT " + DatabaseConstants.READING_SESSION_STORY_HASH + " FROM " + DatabaseConstants.READING_SESSION_TABLE + ")",
                        null);
        }
    }

    public void cleanupStoryText() {
        String q = "DELETE FROM " + DatabaseConstants.STORY_TEXT_TABLE +
                   " WHERE " + DatabaseConstants.STORY_TEXT_STORY_HASH + " NOT IN " +
                   "( SELECT " + DatabaseConstants.STORY_HASH + " FROM " + DatabaseConstants.STORY_TABLE +
                   ")";
        synchronized (RW_MUTEX) {dbRW.execSQL(q);}
    }

    public void vacuum() {
        synchronized (RW_MUTEX) {dbRW.execSQL("VACUUM");}
    }

    public void deleteFeed(String feedId) {
        String[] selArgs = new String[] {feedId};
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.FEED_TABLE, DatabaseConstants.FEED_ID + " = ?", selArgs);}
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.STORY_TABLE, DatabaseConstants.STORY_FEED_ID + " = ?", selArgs);}
    }

    public void deleteSocialFeed(String userId) {
        String[] selArgs = new String[] {userId};
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.SOCIALFEED_TABLE, DatabaseConstants.SOCIAL_FEED_ID + " = ?", selArgs);}
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.STORY_TABLE, DatabaseConstants.STORY_FEED_ID + " = ?", selArgs);}
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE, DatabaseConstants.SOCIALFEED_STORY_USER_ID + " = ?", selArgs);}
    }

    public Feed getFeed(String feedId) {
        Cursor c = dbRO.query(DatabaseConstants.FEED_TABLE, null,  DatabaseConstants.FEED_ID + " = ?", new String[] {feedId}, null, null, null);
        Feed result = null;
        while (c.moveToNext()) {
            result = Feed.fromCursor(c);
        }
        c.close();
        return result;
    }

    private void bulkInsertValues(String table, List<ContentValues> valuesList) {
        if (valuesList.size() < 1) return;
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                for (ContentValues values : valuesList) {
                    dbRW.insertWithOnConflict(table, null, values, SQLiteDatabase.CONFLICT_REPLACE);
                }
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    // just like bulkInsertValues, but leaves sync/transactioning to the caller
    private void bulkInsertValuesExtSync(String table, List<ContentValues> valuesList) {
        if (valuesList.size() < 1) return;
        for (ContentValues values : valuesList) {
            dbRW.insertWithOnConflict(table, null, values, SQLiteDatabase.CONFLICT_REPLACE);
        }
    }

    public void setFeedsFolders(List<ContentValues> folderValues,
                                List<ContentValues> feedValues,
                                List<ContentValues> socialFeedValues,
                                List<ContentValues> starredCountValues) {
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                dbRW.delete(DatabaseConstants.FEED_TABLE, null, null);
                dbRW.delete(DatabaseConstants.FOLDER_TABLE, null, null);
                dbRW.delete(DatabaseConstants.SOCIALFEED_TABLE, null, null);
                dbRW.delete(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE, null, null);
                dbRW.delete(DatabaseConstants.COMMENT_TABLE, null, null);
                dbRW.delete(DatabaseConstants.REPLY_TABLE, null, null);
                dbRW.delete(DatabaseConstants.STARREDCOUNTS_TABLE, null, null);
                bulkInsertValuesExtSync(DatabaseConstants.FOLDER_TABLE, folderValues);
                bulkInsertValuesExtSync(DatabaseConstants.FEED_TABLE, feedValues);
                bulkInsertValuesExtSync(DatabaseConstants.SOCIALFEED_TABLE, socialFeedValues);
                bulkInsertValuesExtSync(DatabaseConstants.STARREDCOUNTS_TABLE, starredCountValues);
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    public void setStarredCounts(List<ContentValues> values) {
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                dbRW.delete(DatabaseConstants.STARREDCOUNTS_TABLE, null, null);
                bulkInsertValuesExtSync(DatabaseConstants.STARREDCOUNTS_TABLE, values);
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    public List<String> getStoryHashesForFeed(String feedId) {
        String q = "SELECT " + DatabaseConstants.STORY_HASH + 
                   " FROM " + DatabaseConstants.STORY_TABLE +
                   " WHERE " + DatabaseConstants.STORY_FEED_ID + " = ?";
        Cursor c = dbRO.rawQuery(q, new String[]{feedId});
        List<String> hashes = new ArrayList<String>(c.getCount());
        while (c.moveToNext()) {
           hashes.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_HASH)));
        }
        c.close();
        return hashes;
    }

    // note method name: this gets a set rather than a list, in case the caller wants to
    // spend the up-front cost of hashing for better lookup speed rather than iteration!
    public Set<String> getUnreadStoryHashesAsSet() {
        String q = "SELECT " + DatabaseConstants.STORY_HASH + 
                   " FROM " + DatabaseConstants.STORY_TABLE +
                   " WHERE " + DatabaseConstants.STORY_READ + " = 0" ;
        Cursor c = dbRO.rawQuery(q, null);
        Set<String> hashes = new HashSet<String>(c.getCount());
        while (c.moveToNext()) {
           hashes.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_HASH)));
        }
        c.close();
        return hashes;
    }

    public Set<String> getAllStoryImages() {
        Cursor c = dbRO.query(DatabaseConstants.STORY_TABLE, new String[]{DatabaseConstants.STORY_IMAGE_URLS}, null, null, null, null, null);
        Set<String> urls = new HashSet<String>(c.getCount());
        while (c.moveToNext()) {
            for (String url : TextUtils.split(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_IMAGE_URLS)), ",")) {
                urls.add(url);
            }
        }
        c.close();
        return urls;
    }

    public Set<String> getAllStoryThumbnails() {
        Cursor c = dbRO.query(DatabaseConstants.STORY_TABLE, new String[]{DatabaseConstants.STORY_THUMBNAIL_URL}, null, null, null, null, null);
        Set<String> urls = new HashSet<String>(c.getCount());
        while (c.moveToNext()) {
            String url = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_THUMBNAIL_URL));
            if (url != null) {
                urls.add(url);
            }
        }
        c.close();
        return urls;
    }

    public void insertStories(StoriesResponse apiResponse, boolean forImmediateReading) {
        StateFilter intelState = PrefsUtils.getStateFilter(context);
        synchronized (RW_MUTEX) {
            // do not attempt to use beginTransactionNonExclusive() to reduce lock time for this very heavy set
            // of calls. most versions of Android incorrectly implement the underlying SQLite calls and will
            // result in crashes that poison the DB beyond repair
            dbRW.beginTransaction();
            try {
            
                // to insert classifiers, we need to determine the feed ID of the stories in this
                // response, so sniff one out.
                String impliedFeedId = null;

                // handle users
                if (apiResponse.users != null) {
                    List<ContentValues> userValues = new ArrayList<ContentValues>(apiResponse.users.length);
                    for (UserProfile user : apiResponse.users) {
                        userValues.add(user.getValues());
                    }
                    bulkInsertValuesExtSync(DatabaseConstants.USER_TABLE, userValues);
                }

                // handle supplemental feed data that may have been included (usually in social requests)
                if (apiResponse.feeds != null) {
                    List<ContentValues> feedValues = new ArrayList<ContentValues>(apiResponse.feeds.size());
                    for (Feed feed : apiResponse.feeds) {
                        feedValues.add(feed.getValues());
                    }
                    bulkInsertValuesExtSync(DatabaseConstants.FEED_TABLE, feedValues);
                }

                // handle story content
                List<ContentValues> socialStoryValues = new ArrayList<ContentValues>();
                for (Story story : apiResponse.stories) {
                    // pick a thumbnail for the story
                    story.thumbnailUrl = Story.guessStoryThumbnailURL(story);
                    // insert the story data
                    ContentValues values = story.getValues();
                    dbRW.insertWithOnConflict(DatabaseConstants.STORY_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
                    // if a story was shared by a user, also insert it into the social table under their userid, too
                    for (String sharedUserId : story.sharedUserIds) {
                        ContentValues socialValues = new ContentValues();
                        socialValues.put(DatabaseConstants.SOCIALFEED_STORY_USER_ID, sharedUserId);
                        socialValues.put(DatabaseConstants.SOCIALFEED_STORY_STORYID, values.getAsString(DatabaseConstants.STORY_ID));
                        socialStoryValues.add(socialValues);
                    }
                    // if the story is being fetched for the immediate session, also add the hash to the session table
                    if (forImmediateReading && story.isStoryVisibileInState(intelState)) {
                        ContentValues sessionHashValues = new ContentValues();
                        sessionHashValues.put(DatabaseConstants.READING_SESSION_STORY_HASH, story.storyHash);
                        dbRW.insert(DatabaseConstants.READING_SESSION_TABLE, null, sessionHashValues);
                    }
                    impliedFeedId = story.feedId;
                }
                if (socialStoryValues.size() > 0) {
                    for(ContentValues values: socialStoryValues) {
                        dbRW.insertWithOnConflict(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
                    }
                }

                // handle classifiers
                if (apiResponse.classifiers != null) {
                    for (Map.Entry<String,Classifier> entry : apiResponse.classifiers.entrySet()) {
                        // the API might not have included a feed ID, in which case it deserialized as -1 and must be implied
                        String classifierFeedId = entry.getKey();
                        if (classifierFeedId.equals("-1")) {
                            classifierFeedId = impliedFeedId;
                        }
                        List<ContentValues> classifierValues = entry.getValue().getContentValues();
                        for (ContentValues values : classifierValues) {
                            values.put(DatabaseConstants.CLASSIFIER_ID, classifierFeedId);
                        }
                        dbRW.delete(DatabaseConstants.CLASSIFIER_TABLE, DatabaseConstants.CLASSIFIER_ID + " = ?", new String[] { classifierFeedId });
                        bulkInsertValuesExtSync(DatabaseConstants.CLASSIFIER_TABLE, classifierValues);
                    }
                }

                // handle comments
                List<ContentValues> commentValues = new ArrayList<ContentValues>();
                List<ContentValues> replyValues = new ArrayList<ContentValues>();
                // track which comments were seen, so replies can be cleared before re-insertion. there isn't
                // enough data to de-dupe them for an insert/update operation
                List<String> freshCommentIds = new ArrayList<String>();
                for (Story story : apiResponse.stories) {
                    for (Comment comment : story.publicComments) {
                        comment.storyId = story.id;
                        // we need a primary key for comments, so construct one
                        comment.id = Comment.constructId(story.id, story.feedId, comment.userId);
                        commentValues.add(comment.getValues());
                        for (Reply reply : comment.replies) {
                            reply.commentId = comment.id;
                            reply.id = reply.constructId();
                            replyValues.add(reply.getValues());
                        }
                        freshCommentIds.add(comment.id);
                    }
                    for (Comment comment : story.friendsComments) {
                        comment.storyId = story.id;
                        // we need a primary key for comments, so construct one
                        comment.id = Comment.constructId(story.id, story.feedId, comment.userId);
                        comment.byFriend = true;
                        commentValues.add(comment.getValues());
                        for (Reply reply : comment.replies) {
                            reply.commentId = comment.id;
                            reply.id = reply.constructId();
                            replyValues.add(reply.getValues());
                        }
                        freshCommentIds.add(comment.id);
                    }
                    for (Comment comment : story.friendsShares) {
                        comment.isPseudo = true;
                        comment.storyId = story.id;
                        // we need a primary key for comments, so construct one
                        comment.id = Comment.constructId(story.id, story.feedId, comment.userId);
                        comment.byFriend = true;
                        commentValues.add(comment.getValues());
                        for (Reply reply : comment.replies) {
                            reply.commentId = comment.id;
                            reply.id = reply.constructId();
                            replyValues.add(reply.getValues());
                        }
                        freshCommentIds.add(comment.id);
                    }
                }
                // before inserting new replies, remove existing ones for the fetched comments
                // NB: attempting to do this with a "WHERE col IN (vector)" for speed can cause errors on some versions of sqlite
                for (String commentId : freshCommentIds) {
                    dbRW.delete(DatabaseConstants.REPLY_TABLE, DatabaseConstants.REPLY_COMMENTID + " = ?", new String[]{commentId});
                }
                bulkInsertValuesExtSync(DatabaseConstants.COMMENT_TABLE, commentValues);
                bulkInsertValuesExtSync(DatabaseConstants.REPLY_TABLE, replyValues);

                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    public void fixMissingStoryFeeds(Story[] stories) {
        // start off with feeds mentioned by the set of stories
        Set<String> feedIds = new HashSet<String>();
        for (Story story : stories) {
            feedIds.add(story.feedId);
        }
        // now prune any we already have
        String q1 = "SELECT " + DatabaseConstants.FEED_ID +
                    " FROM " + DatabaseConstants.FEED_TABLE;
        Cursor c = dbRO.rawQuery(q1, null);
        while (c.moveToNext()) {
           feedIds.remove(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.FEED_ID)));
        }
        c.close();
        // if any feeds are left, they are phantoms and need a fake entry
        if (feedIds.size() < 1) return;
        android.util.Log.i(this.getClass().getName(), "inserting missing metadata for " + feedIds.size() + " feeds used by new stories");
        List<ContentValues> feedValues = new ArrayList<ContentValues>(feedIds.size());
        for (String feedId : feedIds) {
            Feed missingFeed = Feed.getZeroFeed();
            missingFeed.feedId = feedId;
            feedValues.add(missingFeed.getValues());
        }
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                for (ContentValues values : feedValues) {
                    dbRW.insertWithOnConflict(DatabaseConstants.FEED_TABLE, null, values, SQLiteDatabase.CONFLICT_IGNORE);
                }
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    public Folder getFolder(String folderName) {
        String[] selArgs = new String[] {folderName};
        String selection = DatabaseConstants.FOLDER_NAME + " = ?";
        Cursor c = dbRO.query(DatabaseConstants.FOLDER_TABLE, null, selection, selArgs, null, null, null);
        if (c.getCount() < 1) {
            closeQuietly(c);
            return null;
        }
        Folder folder = Folder.fromCursor(c);
        closeQuietly(c);
        return folder;
    }

    public void touchStory(String hash) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_LAST_READ_DATE, (new Date()).getTime());
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_LAST_READ_DATE + " < 1 AND " + DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});}
    }

    public void markStoryHashesRead(Collection<String> hashes) {
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                ContentValues values = new ContentValues();
                values.put(DatabaseConstants.STORY_READ, true);
                for (String hash : hashes) {
                    dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});
                }
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    /**
     * Marks a story (un)read but does not adjust counts. Must stay idempotent an time-insensitive.
     */
    public void setStoryReadState(String hash, boolean read) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_READ, read);
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});}
    }

    /**
     * Marks a story (un)read and also adjusts unread counts for it. Non-idempotent by design.
     *
     * @return the set of feed IDs that potentially have counts impacted by the mark.
     */
    public Set<FeedSet> setStoryReadState(Story story, boolean read) {
        // calculate the impact surface so the caller can re-check counts if needed
        Set<FeedSet> impactedFeeds = new HashSet<FeedSet>();
        impactedFeeds.add(FeedSet.singleFeed(story.feedId));
        Set<String> socialIds = new HashSet<String>();
        if (!TextUtils.isEmpty(story.socialUserId)) {
            socialIds.add(story.socialUserId);
        }
        if (story.friendUserIds != null) {
            for (String id : story.friendUserIds) {
                socialIds.add(id);
            }
        }
        if (socialIds.size() > 0) {
            impactedFeeds.add(FeedSet.multipleSocialFeeds(socialIds));
        }
        // check the story's starting state and the desired state and adjust it as an atom so we
        // know if it truly changed or not
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                // get a fresh copy of the story from the DB so we know if it changed
                Cursor c = dbRW.query(DatabaseConstants.STORY_TABLE, 
                                      new String[]{DatabaseConstants.STORY_READ}, 
                                      DatabaseConstants.STORY_HASH + " = ?", 
                                      new String[]{story.storyHash}, 
                                      null, null, null);
                if (c.getCount() < 1) {
                    Log.w(this.getClass().getName(), "story removed before finishing mark-read");
                    return impactedFeeds;
                }
                c.moveToFirst();
                boolean origState = (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.STORY_READ)) > 0);
                c.close();
                // if there is nothing to be done, halt
                if (origState == read) {
                    dbRW.setTransactionSuccessful();
                    return impactedFeeds;
                }
                // update the story's read state
                ContentValues values = new ContentValues();
                values.put(DatabaseConstants.STORY_READ, read);
                dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{story.storyHash});
                // which column to inc/dec depends on story intel
                String impactedCol;
                String impactedSocialCol;
                if (story.intelligence.calcTotalIntel() < 0) {
                    // negative stories don't affect counts
                    dbRW.setTransactionSuccessful();
                    return impactedFeeds;
                } else if (story.intelligence.calcTotalIntel() == 0 ) {
                    impactedCol = DatabaseConstants.FEED_NEUTRAL_COUNT;
                    impactedSocialCol = DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT;
                } else {
                    impactedCol = DatabaseConstants.FEED_POSITIVE_COUNT;
                    impactedSocialCol = DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT;
                }
                String operator = (read ? " - 1" : " + 1");
                StringBuilder q = new StringBuilder("UPDATE " + DatabaseConstants.FEED_TABLE);
                q.append(" SET ").append(impactedCol).append(" = ").append(impactedCol).append(operator);
                q.append(" WHERE " + DatabaseConstants.FEED_ID + " = ").append(story.feedId);
                dbRW.execSQL(q.toString());
                for (String socialId : socialIds) {
                    q = new StringBuilder("UPDATE " + DatabaseConstants.SOCIALFEED_TABLE);
                    q.append(" SET ").append(impactedSocialCol).append(" = ").append(impactedSocialCol).append(operator);
                    q.append(" WHERE " + DatabaseConstants.SOCIAL_FEED_ID + " = ").append(socialId);
                    dbRW.execSQL(q.toString());
                }
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
        return impactedFeeds;
    }

    /**
     * Marks a range of stories in a subset of feeds as read. Does not update unread counts;
     * the caller must use updateLocalFeedCounts() or the /reader/feed_unread_count API.
     */
    public void markStoriesRead(FeedSet fs, Long olderThan, Long newerThan) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_READ, true);
        String rangeSelection = null;
        if (olderThan != null) rangeSelection = DatabaseConstants.STORY_TIMESTAMP + " <= " + olderThan.toString();
        if (newerThan != null) rangeSelection = DatabaseConstants.STORY_TIMESTAMP + " >= " + newerThan.toString();
        StringBuilder feedSelection = null;
        if (fs.isAllNormal()) {
            // a null selection is fine for all stories
        } else if (fs.getMultipleFeeds() != null) {
            feedSelection = new StringBuilder(DatabaseConstants.STORY_FEED_ID + " IN ( ");
            feedSelection.append(TextUtils.join(",", fs.getMultipleFeeds()));
            feedSelection.append(")");
        } else if (fs.getSingleFeed() != null) {
            feedSelection= new StringBuilder(DatabaseConstants.STORY_FEED_ID + " = ");
            feedSelection.append(fs.getSingleFeed());
        } else if (fs.getSingleSocialFeed() != null) {
            feedSelection= new StringBuilder(DatabaseConstants.STORY_SOCIAL_USER_ID + " = ");
            feedSelection.append(fs.getSingleSocialFeed().getKey());
        } else {
            throw new IllegalStateException("Asked to mark stories for FeedSet of unknown type.");
        }
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.STORY_TABLE, values, conjoinSelections(feedSelection, rangeSelection), null);}
    }

    /**
     * Get the unread count for the given feedset based on the totals in the feeds table.
     */
    public int getUnreadCount(FeedSet fs, StateFilter stateFilter) {
        // if reading in starred-only mode, there are no unreads, since stories vended as starred are never unread
        if (fs.isFilterSaved()) return 0;
        if (fs.isAllNormal()) {
            return getFeedsUnreadCount(stateFilter, null, null);
        } else if (fs.isAllSocial()) {
            //return getSocialFeedsUnreadCount(stateFilter, null, null);
            // even though we can count up and total the unreads in social feeds, the API doesn't vend
            // unread status for stories viewed when reading All Shared Stories, so force this to 0.
            return 0;
        } else if (fs.getMultipleFeeds() != null) { 
            StringBuilder selection = new StringBuilder(DatabaseConstants.FEED_ID + " IN ( ");
            selection.append(TextUtils.join(",", fs.getMultipleFeeds())).append(")");
            return getFeedsUnreadCount(stateFilter, selection.toString(), null);
        } else if (fs.getMultipleSocialFeeds() != null) {
            StringBuilder selection = new StringBuilder(DatabaseConstants.SOCIAL_FEED_ID + " IN ( ");
            selection.append(TextUtils.join(",", fs.getMultipleFeeds())).append(")");
            return getSocialFeedsUnreadCount(stateFilter, selection.toString(), null);
        } else if (fs.getSingleFeed() != null) {
            return getFeedsUnreadCount(stateFilter, DatabaseConstants.FEED_ID + " = ?", new String[]{fs.getSingleFeed()});
        } else if (fs.getSingleSocialFeed() != null) {
            return getSocialFeedsUnreadCount(stateFilter, DatabaseConstants.SOCIAL_FEED_ID + " = ?", new String[]{fs.getSingleSocialFeed().getKey()});
        } else {
            // all other types of view don't track unreads correctly
            return 0;
        }
    }

    private int getFeedsUnreadCount(StateFilter stateFilter, String selection, String[] selArgs) {
        int result = 0;
        Cursor c = dbRO.query(DatabaseConstants.FEED_TABLE, null, selection, selArgs, null, null, null);
        while (c.moveToNext()) {
            Feed f = Feed.fromCursor(c);
            result += f.positiveCount;
            if ((stateFilter == StateFilter.SOME) || (stateFilter == StateFilter.ALL)) result += f.neutralCount;
            if (stateFilter == StateFilter.ALL) result += f.negativeCount;
        }
        c.close();
        return result;
    }

    private int getSocialFeedsUnreadCount(StateFilter stateFilter, String selection, String[] selArgs) {
        int result = 0;
        Cursor c = dbRO.query(DatabaseConstants.SOCIALFEED_TABLE, null, selection, selArgs, null, null, null);
        while (c.moveToNext()) {
            SocialFeed f = SocialFeed.fromCursor(c);
            result += f.positiveCount;
            if ((stateFilter == StateFilter.SOME) || (stateFilter == StateFilter.ALL)) result += f.neutralCount;
            if (stateFilter == StateFilter.ALL) result += f.negativeCount;
        }
        c.close();
        return result;
    }

    public void updateFeedCounts(String feedId, ContentValues values) {
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.FEED_TABLE, values, DatabaseConstants.FEED_ID + " = ?", new String[]{feedId});}
    }

    public void updateSocialFeedCounts(String feedId, ContentValues values) {
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.SOCIALFEED_TABLE, values, DatabaseConstants.SOCIAL_FEED_ID + " = ?", new String[]{feedId});}
    }

    /**
     * Refreshes the counts in the feeds/socialfeeds tables by counting stories in the story table.
     */
    public void updateLocalFeedCounts(FeedSet fs) {
        // decompose the FeedSet into a list of single feeds that need to be recounted
        List<String> feedIds = new ArrayList<String>();
        List<String> socialFeedIds = new ArrayList<String>();

        if (fs.isAllNormal()) {
            feedIds.addAll(getAllFeeds());
            socialFeedIds.addAll(getAllSocialFeeds());
        } else if (fs.getMultipleFeeds() != null) { 
            feedIds.addAll(fs.getMultipleFeeds());
        } else if (fs.getSingleFeed() != null) {
            feedIds.add(fs.getSingleFeed());
        } else if (fs.getSingleSocialFeed() != null) {
            socialFeedIds.add(fs.getSingleSocialFeed().getKey());
        } else if (fs.getMultipleSocialFeeds() != null) {
            socialFeedIds.addAll(fs.getMultipleSocialFeeds().keySet());
        } else {
            throw new IllegalStateException("Asked to refresh story counts for FeedSet of unknown type.");
        }

        // now recount the number of unreads in each feed, one by one
        for (String feedId : feedIds) {
            FeedSet singleFs = FeedSet.singleFeed(feedId);
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, getLocalUnreadCount(singleFs, StateFilter.NEG));
            values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, getLocalUnreadCount(singleFs, StateFilter.NEUT));
            values.put(DatabaseConstants.FEED_POSITIVE_COUNT, getLocalUnreadCount(singleFs, StateFilter.BEST));
            synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.FEED_TABLE, values, DatabaseConstants.FEED_ID + " = ?", new String[]{feedId});}
        }

        for (String socialId : socialFeedIds) {
            FeedSet singleFs = FeedSet.singleSocialFeed(socialId, "");
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, getLocalUnreadCount(singleFs, StateFilter.NEG));
            values.put(DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, getLocalUnreadCount(singleFs, StateFilter.NEUT));
            values.put(DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT, getLocalUnreadCount(singleFs, StateFilter.BEST));
            synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.SOCIALFEED_TABLE, values, DatabaseConstants.SOCIAL_FEED_ID + " = ?", new String[]{socialId});}
        }
    }

    /**
     * Get the unread count for the given feedset based on local story state.
     */
    public int getLocalUnreadCount(FeedSet fs, StateFilter stateFilter) {
        StringBuilder sel = new StringBuilder();
        ArrayList<String> selArgs = new ArrayList<String>();
        getLocalStorySelectionAndArgs(sel, selArgs, fs, stateFilter, ReadFilter.UNREAD);

        Cursor c = dbRO.rawQuery(sel.toString(), selArgs.toArray(new String[selArgs.size()]));
        int count = c.getCount();
        c.close();
        return count;
    }

    public void enqueueAction(ReadingAction ra) {
        synchronized (RW_MUTEX) {dbRW.insertOrThrow(DatabaseConstants.ACTION_TABLE, null, ra.toContentValues());}
    }

    public Cursor getActions(boolean includeDone) {
        String q = "SELECT * FROM " + DatabaseConstants.ACTION_TABLE;
        return dbRO.rawQuery(q, null);
    }

    public void clearAction(String actionId) {
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.ACTION_TABLE, DatabaseConstants.ACTION_ID + " = ?", new String[]{actionId});}
    }

    public void setStoryStarred(String hash, boolean starred) {
        // check the story's starting state and the desired state and adjust it as an atom so we
        // know if it truly changed or not and thus whether to update counts
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                // get a fresh copy of the story from the DB so we know if it changed
                Cursor c = dbRW.query(DatabaseConstants.STORY_TABLE, 
                                      new String[]{DatabaseConstants.STORY_STARRED}, 
                                      DatabaseConstants.STORY_HASH + " = ?", 
                                      new String[]{hash}, 
                                      null, null, null);
                if (c.getCount() < 1) {
                    Log.w(this.getClass().getName(), "story removed before finishing mark-starred");
                    return;
                }
                c.moveToFirst();
                boolean origState = (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.STORY_STARRED)) > 0);
                c.close();
                // if there is nothing to be done, halt
                if (origState == starred) {
                    return;
                }
                // fix the state
                ContentValues values = new ContentValues();
                values.put(DatabaseConstants.STORY_STARRED, starred);
                dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});
                // adjust counts
                String operator = (starred ? " + 1" : " - 1");
                StringBuilder q = new StringBuilder("UPDATE " + DatabaseConstants.STARREDCOUNTS_TABLE);
                q.append(" SET " + DatabaseConstants.STARREDCOUNTS_COUNT + " = " + DatabaseConstants.STARREDCOUNTS_COUNT).append(operator);
                q.append(" WHERE " + DatabaseConstants.STARREDCOUNTS_TAG + " = '" + StarredCount.TOTAL_STARRED + "'");
                // TODO: adjust counts per feed (and tags?)
                dbRW.execSQL(q.toString());
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    public void setStoryShared(String hash) {
        // get a fresh copy of the story from the DB so we can append to the shared ID set
        Cursor c = dbRO.query(DatabaseConstants.STORY_TABLE, 
                              new String[]{DatabaseConstants.STORY_SHARED_USER_IDS}, 
                              DatabaseConstants.STORY_HASH + " = ?", 
                              new String[]{hash}, 
                              null, null, null);
        if ((c == null)||(c.getCount() < 1)) {
            Log.w(this.getClass().getName(), "story removed before finishing mark-shared");
            closeQuietly(c);
            return;
        }
        c.moveToFirst();
		String[] sharedUserIds = TextUtils.split(c.getString(c.getColumnIndex(DatabaseConstants.STORY_SHARED_USER_IDS)), ",");
        closeQuietly(c);

        // the new id to append to the shared list (the current user)
        String currentUser = PrefsUtils.getUserDetails(context).id;

        // append to set and update DB
        Set<String> newIds = new HashSet<String>(Arrays.asList(sharedUserIds));
        newIds.add(currentUser);
        ContentValues values = new ContentValues();
		values.put(DatabaseConstants.STORY_SHARED_USER_IDS, TextUtils.join(",", newIds));
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});}
    }

    public String getStoryText(String hash) {
        String q = "SELECT " + DatabaseConstants.STORY_TEXT_STORY_TEXT +
                   " FROM " + DatabaseConstants.STORY_TEXT_TABLE +
                   " WHERE " + DatabaseConstants.STORY_TEXT_STORY_HASH + " = ?";
        Cursor c = dbRO.rawQuery(q, new String[]{hash});
        if (c.getCount() < 1) {
            c.close();
            return null;
        } else {
            c.moveToFirst();
            String result = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_TEXT_STORY_TEXT));
            c.close();
            return result;
        }
    }

    public String getStoryContent(String hash) {
        String q = "SELECT " + DatabaseConstants.STORY_CONTENT +
                   " FROM " + DatabaseConstants.STORY_TABLE +
                   " WHERE " + DatabaseConstants.STORY_HASH + " = ?";
        Cursor c = dbRO.rawQuery(q, new String[]{hash});
        if (c.getCount() < 1) {
            c.close();
            return null;
        } else {
            c.moveToFirst();
            String result = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_CONTENT));
            c.close();
            return result;
        }
    }

    public void putStoryText(String hash, String text) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_TEXT_STORY_HASH, hash);
        values.put(DatabaseConstants.STORY_TEXT_STORY_TEXT, text);
        synchronized (RW_MUTEX) {dbRW.insertOrThrow(DatabaseConstants.STORY_TEXT_TABLE, null, values);}
    }

    public Loader<Cursor> getSocialFeedsLoader(final StateFilter stateFilter) {
        return new QueryCursorLoader(context) {
            protected Cursor createCursor() {return getSocialFeedsCursor(stateFilter, cancellationSignal);}
        };
    }

    public Cursor getSocialFeedsCursor(StateFilter stateFilter, CancellationSignal cancellationSignal) {
        return query(false, DatabaseConstants.SOCIALFEED_TABLE, null, DatabaseConstants.getBlogSelectionFromState(stateFilter), null, null, null, "UPPER(" + DatabaseConstants.SOCIAL_FEED_TITLE + ") ASC", null, cancellationSignal);
    }

    public SocialFeed getSocialFeed(String feedId) {
        Cursor c = dbRO.query(DatabaseConstants.SOCIALFEED_TABLE, null, DatabaseConstants.SOCIAL_FEED_ID + " = ?", new String[] {feedId}, null, null, null);
        SocialFeed result = null;
        while (c.moveToNext()) {
            result = SocialFeed.fromCursor(c);
        }
        c.close();
        return result;
    }

    public List<Folder> getFolders() {
        Cursor c = getFoldersCursor(null);
        List<Folder> folders = new ArrayList<Folder>(c.getCount());
        while (c.moveToNext()) {
            folders.add(Folder.fromCursor(c));
        }
        c.close();
        return folders;
    }

    public Loader<Cursor> getFoldersLoader() {
        return new QueryCursorLoader(context) {
            protected Cursor createCursor() {return getFoldersCursor(cancellationSignal);}
        };
    }

    public Cursor getFoldersCursor(CancellationSignal cancellationSignal) {
        return query(false, DatabaseConstants.FOLDER_TABLE, null, null, null, null, null, null, null, cancellationSignal);
    }

    public Loader<Cursor> getFeedsLoader(final StateFilter stateFilter) {
        return new QueryCursorLoader(context) {
            protected Cursor createCursor() {return getFeedsCursor(stateFilter, cancellationSignal);}
        };
    }

    public Cursor getFeedsCursor(StateFilter stateFilter, CancellationSignal cancellationSignal) {
        return query(false, DatabaseConstants.FEED_TABLE, null, DatabaseConstants.getFeedSelectionFromState(stateFilter), null, null, null, "UPPER(" + DatabaseConstants.FEED_TITLE + ") ASC", null, cancellationSignal);
    }

    public Loader<Cursor> getSavedStoryCountsLoader() {
        return new QueryCursorLoader(context) {
            protected Cursor createCursor() {return getSavedStoryCountsCursor(cancellationSignal);}
        };
    }

    private Cursor getSavedStoryCountsCursor(CancellationSignal cancellationSignal) {
        Cursor c = query(false, DatabaseConstants.STARREDCOUNTS_TABLE, null, null, null, null, null, null, null, cancellationSignal);
        return c;
    }

    public Loader<Cursor> getActiveStoriesLoader(final FeedSet fs) {
        final StoryOrder order = PrefsUtils.getStoryOrder(context, fs);
        return new QueryCursorLoader(context) {
            protected Cursor createCursor() {
                return getActiveStoriesCursor(fs, order, cancellationSignal);
            }
        };
    }

    private Cursor getActiveStoriesCursor(FeedSet fs, StoryOrder order, CancellationSignal cancellationSignal) {
        // get the stories for this FS
        Cursor result = getActiveStoriesCursorNoPrep(fs, order, cancellationSignal);
        // if the result is blank, try to prime the session table with existing stories, in case we
        // are offline, but if a session is started, just use what was there so offsets don't change.
        if (result.getCount() < 1) {
            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "priming reading session");
            prepareReadingSession(fs);
            result = getActiveStoriesCursorNoPrep(fs, order, cancellationSignal);
        }
        return result;
    }
    
    private Cursor getActiveStoriesCursorNoPrep(FeedSet fs, StoryOrder order, CancellationSignal cancellationSignal) {
        // stories aren't actually queried directly via the FeedSet and filters set in the UI. rather,
        // those filters are use to push live or cached story hashes into the reading session table, and
        // those hashes are used to pull story data from the story table
        StringBuilder q = new StringBuilder(DatabaseConstants.STORY_QUERY_BASE);
        
        if (fs.isAllRead()) {
            q.append(" ORDER BY " + DatabaseConstants.READ_STORY_ORDER);
        } else if (fs.isAllSaved()) {
            q.append(" ORDER BY " + DatabaseConstants.getSavedStoriesSortOrder(order));
        } else {
            q.append(" ORDER BY ").append(DatabaseConstants.getStorySortOrder(order));
        }
        return rawQuery(q.toString(), null, cancellationSignal);
    }

    public void clearStorySession() {
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.READING_SESSION_TABLE, null, null);}
    }

    public void prepareReadingSession(FeedSet fs) {
        ReadFilter readFilter = PrefsUtils.getReadFilter(context, fs);
        StateFilter stateFilter = PrefsUtils.getStateFilter(context);
        prepareReadingSession(fs, stateFilter, readFilter);
    }

    /**
     * Populates the reading session table with hashes of already-fetched stories that meet the 
     * criteria for the given FeedSet and filters; these hashes will be supplemented by hashes
     * fetched via the API and used to actually select story data when rendering story lists.
     */
    private void prepareReadingSession(FeedSet fs, StateFilter stateFilter, ReadFilter readFilter) {
        // a selection filter that will be used to pull active story hashes from the stories table into the reading session table
        StringBuilder sel = new StringBuilder();
        // any selection args that need to be used within the inner select statement
        ArrayList<String> selArgs = new ArrayList<String>();

        getLocalStorySelectionAndArgs(sel, selArgs, fs, stateFilter, readFilter);

        // use the inner select statement to push the active hashes into the session table
        StringBuilder q = new StringBuilder("INSERT INTO " + DatabaseConstants.READING_SESSION_TABLE);
        q.append(" (" + DatabaseConstants.READING_SESSION_STORY_HASH + ") ");
        q.append(sel);

        synchronized (RW_MUTEX) {dbRW.execSQL(q.toString(), selArgs.toArray(new String[selArgs.size()]));}
    }

    /**
     * Gets hashes of already-fetched stories that satisfy the given FeedSet and filters. Can be used
     * both to populate a reading session or to count local unreads.
     */
    private void getLocalStorySelectionAndArgs(StringBuilder sel, List<String> selArgs, FeedSet fs, StateFilter stateFilter, ReadFilter readFilter) {
        // if the user has requested saved stories, ignore the unreads filter, as saveds do not have this state
        if (fs.isFilterSaved()) {
            readFilter = ReadFilter.ALL;
        }

        sel.append("SELECT " + DatabaseConstants.STORY_HASH);
        if (fs.getSingleFeed() != null) {

            sel.append(" FROM " + DatabaseConstants.STORY_TABLE);
            sel.append(" WHERE " + DatabaseConstants.STORY_FEED_ID + " = ?");
            selArgs.add(fs.getSingleFeed());
            DatabaseConstants.appendStorySelection(sel, selArgs, readFilter, stateFilter, fs.getSearchQuery());

        } else if (fs.getMultipleFeeds() != null) {

            sel.append(" FROM " + DatabaseConstants.STORY_TABLE);
            sel.append(" WHERE " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " IN ( ");
            sel.append(TextUtils.join(",", fs.getMultipleFeeds()) + ")");
            DatabaseConstants.appendStorySelection(sel, selArgs, readFilter, stateFilter, fs.getSearchQuery());

        } else if (fs.getSingleSocialFeed() != null) {

            sel.append(" FROM " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE);
            sel.append(DatabaseConstants.JOIN_STORIES_ON_SOCIALFEED_MAP);
            sel.append(" WHERE " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE + "." + DatabaseConstants.SOCIALFEED_STORY_USER_ID + " = ? ");
            selArgs.add(fs.getSingleSocialFeed().getKey());
            DatabaseConstants.appendStorySelection(sel, selArgs, readFilter, stateFilter, fs.getSearchQuery());

        } else if (fs.isAllNormal()) {

            sel.append(" FROM " + DatabaseConstants.STORY_TABLE);
            sel.append(" WHERE 1");
            DatabaseConstants.appendStorySelection(sel, selArgs, readFilter, stateFilter, fs.getSearchQuery());

        } else if (fs.isAllSocial()) {

            sel.append(" FROM " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE);
            sel.append(DatabaseConstants.JOIN_STORIES_ON_SOCIALFEED_MAP);
            if (stateFilter == StateFilter.SAVED) stateFilter = StateFilter.SOME;
            DatabaseConstants.appendStorySelection(sel, selArgs, readFilter, stateFilter, fs.getSearchQuery());

        } else if (fs.isAllRead()) {

            sel.append(" FROM " + DatabaseConstants.STORY_TABLE);
            sel.append(" WHERE (" + DatabaseConstants.STORY_LAST_READ_DATE + " > 0)");

        } else if (fs.isAllSaved()) {

            sel.append(" FROM " + DatabaseConstants.STORY_TABLE);
            sel.append(" WHERE (" + DatabaseConstants.STORY_STARRED + " = 1)");
            DatabaseConstants.appendStorySelection(sel, selArgs, ReadFilter.ALL, StateFilter.ALL, fs.getSearchQuery());

        } else if (fs.getSingleSavedTag() != null) {

            sel.append(" FROM " + DatabaseConstants.STORY_TABLE);
            sel.append(" WHERE (" + DatabaseConstants.STORY_STARRED + " = 1)");
            sel.append(" AND (" + DatabaseConstants.STORY_USER_TAGS + " LIKE ?)");
            StringBuilder tagArg = new StringBuilder("%");
            tagArg.append(fs.getSingleSavedTag()).append("%");
            selArgs.add(tagArg.toString());
            DatabaseConstants.appendStorySelection(sel, selArgs, ReadFilter.ALL, StateFilter.ALL, fs.getSearchQuery());
            
        } else if (fs.isGlobalShared()) {

            sel.append(" FROM " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE);
            sel.append(DatabaseConstants.JOIN_STORIES_ON_SOCIALFEED_MAP);
            if (stateFilter == StateFilter.SAVED) stateFilter = StateFilter.SOME;
            DatabaseConstants.appendStorySelection(sel, selArgs, readFilter, stateFilter, fs.getSearchQuery());

        } else {
            throw new IllegalStateException("Asked to get stories for FeedSet of unknown type.");
        }
    }

    public void clearClassifiersForFeed(String feedId) {
        String[] selArgs = new String[] {feedId};
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.CLASSIFIER_TABLE, DatabaseConstants.CLASSIFIER_ID + " = ?", selArgs);}
    }

    public void insertClassifier(Classifier classifier) {
        bulkInsertValues(DatabaseConstants.CLASSIFIER_TABLE, classifier.getContentValues());
    }

    public Classifier getClassifierForFeed(String feedId) {
        String[] selArgs = new String[] {feedId};
        Cursor c = dbRO.query(DatabaseConstants.CLASSIFIER_TABLE, null, DatabaseConstants.CLASSIFIER_ID + " = ?", selArgs, null, null, null);
        Classifier classifier = Classifier.fromCursor(c);
        closeQuietly(c);
        return classifier;
    }

    public List<Comment> getComments(String storyId) {
        String[] selArgs = new String[] {storyId};
        String selection = DatabaseConstants.COMMENT_STORYID + " = ?"; 
        Cursor c = dbRO.query(DatabaseConstants.COMMENT_TABLE, null, selection, selArgs, null, null, null);
        List<Comment> comments = new ArrayList<Comment>(c.getCount());
        while (c.moveToNext()) {
            comments.add(Comment.fromCursor(c));
        }
        closeQuietly(c);
        return comments;
    }

    public Comment getComment(String storyId, String userId) {
        String selection = DatabaseConstants.COMMENT_STORYID + " = ? AND " + DatabaseConstants.COMMENT_USERID + " = ?";
        String[] selArgs = new String[] {storyId, userId};
        Cursor c = dbRO.query(DatabaseConstants.COMMENT_TABLE, null, selection, selArgs, null, null, null);
        if (c.getCount() < 1) return null;
        c.moveToFirst();
        Comment comment = Comment.fromCursor(c);
        closeQuietly(c);
        return comment;
    }

    public void insertUpdateComment(String storyId, String feedId, String commentText) {
        // we can only insert comments as the currently logged-in user
        String userId = PrefsUtils.getUserDetails(context).id;

        Comment comment = new Comment();
        comment.id = Comment.constructId(storyId, feedId, userId);
        comment.storyId = storyId;
        comment.userId = userId;
        comment.commentText = commentText;
        comment.byFriend = true;
        if (TextUtils.isEmpty(commentText)) {
            comment.isPseudo = true;
        }
        synchronized (RW_MUTEX) {dbRW.insertWithOnConflict(DatabaseConstants.COMMENT_TABLE, null, comment.getValues(), SQLiteDatabase.CONFLICT_REPLACE);}
    }

    public void setCommentLiked(String storyId, String userId, String feedId, boolean liked) {
        String commentKey = Comment.constructId(storyId, feedId, userId);
        // get a fresh copy of the story from the DB so we can append to the shared ID set
        Cursor c = dbRO.query(DatabaseConstants.COMMENT_TABLE, 
                              new String[]{DatabaseConstants.COMMENT_LIKING_USERS}, 
                              DatabaseConstants.COMMENT_ID + " = ?", 
                              new String[]{commentKey}, 
                              null, null, null);
        if ((c == null)||(c.getCount() < 1)) {
            Log.w(this.getClass().getName(), "story removed before finishing mark-shared");
            closeQuietly(c);
            return;
        }
        c.moveToFirst();
		String[] likingUserIds = TextUtils.split(c.getString(c.getColumnIndex(DatabaseConstants.COMMENT_LIKING_USERS)), ",");
        closeQuietly(c);

        // the new id to append/remove from the liking list (the current user)
        String currentUser = PrefsUtils.getUserDetails(context).id;

        // append to set and update DB
        Set<String> newIds = new HashSet<String>(Arrays.asList(likingUserIds));
        if (liked) {
            newIds.add(currentUser);
        } else {
            newIds.remove(currentUser);
        }
        ContentValues values = new ContentValues();
		values.put(DatabaseConstants.COMMENT_LIKING_USERS, TextUtils.join(",", newIds));
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.COMMENT_TABLE, values, DatabaseConstants.COMMENT_ID + " = ?", new String[]{commentKey});}
    }

    public UserProfile getUserProfile(String userId) {
        String[] selArgs = new String[] {userId};
        String selection = DatabaseConstants.USER_USERID + " = ?";
        Cursor c = dbRO.query(DatabaseConstants.USER_TABLE, null, selection, selArgs, null, null, null);
        UserProfile profile = UserProfile.fromCursor(c);
        closeQuietly(c);
        return profile;
    }

    public List<Reply> getCommentReplies(String commentId) {
        String[] selArgs = new String[] {commentId};
        String selection = DatabaseConstants.REPLY_COMMENTID+ " = ?";
        Cursor c = dbRO.query(DatabaseConstants.REPLY_TABLE, null, selection, selArgs, null, null, DatabaseConstants.REPLY_DATE + " ASC");
        List<Reply> replies = new ArrayList<Reply>(c.getCount());
        while (c.moveToNext()) {
            replies.add(Reply.fromCursor(c));
        }
        closeQuietly(c);
        return replies;
    }

    public void replyToComment(String storyId, String feedId, String commentUserId, String replyText, long replyCreateTime) {
        Reply reply = new Reply();
        reply.commentId = Comment.constructId(storyId, feedId, commentUserId);
        reply.text = replyText;
        reply.userId = PrefsUtils.getUserDetails(context).id;
        reply.date = new Date(replyCreateTime);
        reply.id = reply.constructId();
        synchronized (RW_MUTEX) {dbRW.insertWithOnConflict(DatabaseConstants.REPLY_TABLE, null, reply.getValues(), SQLiteDatabase.CONFLICT_REPLACE);}
    }

    public static void closeQuietly(Cursor c) {
        if (c == null) return;
        try {c.close();} catch (Exception e) {;}
    }

    private static String conjoinSelections(CharSequence... args) {
        StringBuilder s = null;
        for (CharSequence c : args) {
            if (c == null) continue;
            if (s == null) {
                s = new StringBuilder(c);
            } else {
                s.append(" AND ");
                s.append(c);
            }
        }
        if (s == null) return null;
        return s.toString();
    }

    /**
     * Invoke the rawQuery() method on our read-only SQLiteDatabase memeber using the provided CancellationSignal
     * only if the device's platform provides support.
     */
    private Cursor rawQuery(String sql, String[] selectionArgs, CancellationSignal cancellationSignal) {
        if (AppConstants.VERBOSE_LOG_DB) {
            Log.d(this.getClass().getName(), String.format("DB rawQuery: '%s' with args: %s", sql, java.util.Arrays.toString(selectionArgs)));
        }
        return dbRO.rawQuery(sql, selectionArgs, cancellationSignal);
    }

    /**
     * Invoke the query() method on our read-only SQLiteDatabase memeber using the provided CancellationSignal
     * only if the device's platform provides support.
     */
    private Cursor query(boolean distinct, String table, String[] columns, String selection, String[] selectionArgs, String groupBy, String having, String orderBy, String limit, CancellationSignal cancellationSignal) {
        return dbRO.query(distinct, table, columns, selection, selectionArgs, groupBy, having, orderBy, limit, cancellationSignal);
    }

}
