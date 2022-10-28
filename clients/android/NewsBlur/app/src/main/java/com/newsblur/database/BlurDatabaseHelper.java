package com.newsblur.database;

import static java.util.Collections.emptySet;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.CancellationSignal;
import androidx.annotation.Nullable;

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
import com.newsblur.network.domain.CommentResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadingAction;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.UIUtils;

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
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

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
        com.newsblur.util.Log.d(this.getClass().getName(), "new DB conn requested");
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
        ExecutorService executorService = Executors.newSingleThreadExecutor();
        executorService.execute(() -> {
            synchronized (RW_MUTEX) {
                dbWrapper.close();
            }
        });
    }

    public void dropAndRecreateTables() {
        com.newsblur.util.Log.i(this.getClass().getName(), "dropping and recreating all tables . . .");
        synchronized (RW_MUTEX) {dbWrapper.dropAndRecreateTables();}
        com.newsblur.util.Log.i(this.getClass().getName(), ". . . tables recreated.");
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
        return getAllFeeds(false);
    }

    private Set<String> getAllFeeds(boolean activeOnly) {
        String q1 = "SELECT " + DatabaseConstants.FEED_ID +
                    " FROM " + DatabaseConstants.FEED_TABLE;
        if (activeOnly) {
            q1 = q1 + " WHERE " + DatabaseConstants.FEED_ACTIVE + " = 1";
        }
        Cursor c = dbRO.rawQuery(q1, null);
        LinkedHashSet<String> feedIds = new LinkedHashSet<String>(c.getCount());
        while (c.moveToNext()) {
           feedIds.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.FEED_ID)));
        }
        c.close();
        return feedIds;
    }

    public Set<String> getAllActiveFeeds() {
        return getAllFeeds(true);
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
            com.newsblur.util.Log.d(this, "cleaned up ancient stories: " + count);
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
            com.newsblur.util.Log.d(this, "cleaned up read stories: " + count);
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

    public void deleteSavedSearch(String feedId, String query) {
        String q = "DELETE FROM " + DatabaseConstants.SAVED_SEARCH_TABLE +
                " WHERE " + DatabaseConstants.SAVED_SEARCH_FEED_ID + " = '" + feedId + "'" +
                " AND " + DatabaseConstants.SAVED_SEARCH_QUERY + " = '" + query + "'";
        synchronized (RW_MUTEX) {dbRW.execSQL(q);}
    }

    public void deleteStories() {
        vacuum();
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.STORY_TABLE, null, null);}
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.STORY_TEXT_TABLE, null, null);}
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

    public void updateFeed(Feed feed) {
        synchronized (RW_MUTEX) {
            dbRW.insertWithOnConflict(DatabaseConstants.FEED_TABLE, null, feed.getValues(), SQLiteDatabase.CONFLICT_REPLACE);
        }
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
                                List<ContentValues> starredCountValues,
                                List<ContentValues> savedSearchValues) {
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
                dbRW.delete(DatabaseConstants.SAVED_SEARCH_TABLE, null, null);
                bulkInsertValuesExtSync(DatabaseConstants.FOLDER_TABLE, folderValues);
                bulkInsertValuesExtSync(DatabaseConstants.FEED_TABLE, feedValues);
                bulkInsertValuesExtSync(DatabaseConstants.SOCIALFEED_TABLE, socialFeedValues);
                bulkInsertValuesExtSync(DatabaseConstants.STARREDCOUNTS_TABLE, starredCountValues);
                bulkInsertValuesExtSync(DatabaseConstants.SAVED_SEARCH_TABLE, savedSearchValues);
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
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

    public Set<String> getStarredStoryHashes() {
        String q = "SELECT " + DatabaseConstants.STORY_HASH +
                " FROM " + DatabaseConstants.STORY_TABLE +
                " WHERE " + DatabaseConstants.STORY_STARRED + " = 1" ;
        Cursor c = dbRO.rawQuery(q, null);
        Set<String> hashes = new HashSet<>(c.getCount());
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
            urls.addAll(Arrays.asList(TextUtils.split(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_IMAGE_URLS)), ",")));
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
                if (apiResponse.stories != null) {
                    storiesloop: for (Story story : apiResponse.stories) {
                        if ((story.storyHash == null) || (story.storyHash.length() < 1)) {
                            // this is incredibly rare, but has been seen in crash reports at least twice.
                            com.newsblur.util.Log.e(this, "story received without story hash: " + story.id);
                            continue storiesloop;
                        }
                        insertSingleStoryExtSync(story);
                        // if the story is being fetched for the immediate session, also add the hash to the session table
                        if (forImmediateReading && story.isStoryVisibileInState(intelState)) {
                            ContentValues sessionHashValues = new ContentValues();
                            sessionHashValues.put(DatabaseConstants.READING_SESSION_STORY_HASH, story.storyHash);
                            dbRW.insert(DatabaseConstants.READING_SESSION_TABLE, null, sessionHashValues);
                        }
                        impliedFeedId = story.feedId;
                    }
                }
                if (apiResponse.story != null) {
                    if ((apiResponse.story.storyHash == null) || (apiResponse.story.storyHash.length() < 1)) {
                        com.newsblur.util.Log.e(this, "story received without story hash: " + apiResponse.story.id);
                        return;
                    }
                    insertSingleStoryExtSync(apiResponse.story);
                    impliedFeedId = apiResponse.story.feedId;
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

                if (apiResponse.feedTags != null ) {
                    List<String> feedTags = new ArrayList<String>(apiResponse.feedTags.length);
                    for (String[] tuple : apiResponse.feedTags) {
                        // the API returns a list of lists, but all we care about is the tag name/id which is the first item in the tuple
                        if (tuple.length > 0) {
                            feedTags.add(tuple[0]);
                        }
                    }
                    putFeedTagsExtSync(impliedFeedId, feedTags);
                }

                if (apiResponse.feedAuthors != null ) {
                    List<String> feedAuthors = new ArrayList<String>(apiResponse.feedAuthors.length);
                    for (String[] tuple : apiResponse.feedAuthors) {
                        // the API returns a list of lists, but all we care about is the author name/id which is the first item in the tuple
                        if (tuple.length > 0) {
                            feedAuthors.add(tuple[0]);
                        }
                    }
                    putFeedAuthorsExtSync(impliedFeedId, feedAuthors);
                }

                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    private void insertSingleStoryExtSync(Story story) {
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
            dbRW.insertWithOnConflict(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE, null, socialValues, SQLiteDatabase.CONFLICT_REPLACE);
        }
        // handle comments
        for (Comment comment : story.publicComments) {
            comment.storyId = story.id;
            insertSingleCommentExtSync(comment);
        }
        for (Comment comment : story.friendsComments) {
            comment.storyId = story.id;
            comment.byFriend = true;
            insertSingleCommentExtSync(comment);
        }
        for (Comment comment : story.friendsShares) {
            comment.isPseudo = true;
            comment.storyId = story.id;
            comment.byFriend = true;
            insertSingleCommentExtSync(comment);
        }
    }

    private void insertSingleCommentExtSync(Comment comment) {
        // real comments replace placeholders
        int count = dbRW.delete(DatabaseConstants.COMMENT_TABLE, DatabaseConstants.COMMENT_ISPLACEHOLDER + " = ?", new String[]{"true"});
        // comments always come with an updated set of replies, so remove old ones first
        dbRW.delete(DatabaseConstants.REPLY_TABLE, DatabaseConstants.REPLY_COMMENTID + " = ?", new String[]{comment.id});
        dbRW.insertWithOnConflict(DatabaseConstants.COMMENT_TABLE, null, comment.getValues(), SQLiteDatabase.CONFLICT_REPLACE);
        for (Reply reply : comment.replies) {
            reply.commentId = comment.id;
            dbRW.insertWithOnConflict(DatabaseConstants.REPLY_TABLE, null, reply.getValues(), SQLiteDatabase.CONFLICT_REPLACE);
        }
    }

    /**
     * Update an existing story based upon a new copy received from a social API. This handles the fact
     * that some social APIs helpfully vend updated copies of stories with social-related fields updated
     * to reflect a social action, but that the new copy is missing some fields.  Attempt to merge the
     * new story with the old one.
     */
    public void updateStory(StoriesResponse apiResponse, boolean forImmediateReading) {
        if (apiResponse.story == null) {
            com.newsblur.util.Log.e(this, "updateStory called on response with missing single story");
            return;
        }
        Cursor c = dbRO.query(DatabaseConstants.STORY_TABLE, 
                              null, 
                              DatabaseConstants.STORY_HASH + " = ?", 
                              new String[]{apiResponse.story.storyHash}, 
                              null, null, null);
        if (c.getCount() < 1) {
            com.newsblur.util.Log.w(this, "updateStory can't find old copy; new story may be missing fields.");
        } else {
            Story oldStory = Story.fromCursor(c);
            c.close();
            apiResponse.story.starred = oldStory.starred;
            apiResponse.story.starredTimestamp = oldStory.starredTimestamp;
            apiResponse.story.read = oldStory.read;
        }
        insertStories(apiResponse, forImmediateReading);
    }

    /**
     * Update an existing comment and associated replies based upon a new copy received from a social
     * API.  Most social APIs vend an updated view that replaces any old or placeholder records.
     */
    public void updateComment(CommentResponse apiResponse, String storyId) {
        synchronized (RW_MUTEX) {
            // comments often contain enclosed replies, so batch them.
            dbRW.beginTransaction();
            try {
                // the API might include new supplemental user metadata if new replies have shown up.
                if (apiResponse.users != null) {
                    List<ContentValues> userValues = new ArrayList<ContentValues>(apiResponse.users.length);
                    for (UserProfile user : apiResponse.users) {
                        userValues.add(user.getValues());
                    }
                    bulkInsertValuesExtSync(DatabaseConstants.USER_TABLE, userValues);
                }

                // we store all comments in the context of the associated story, but the social API doesn't
                // reference the story when responding, so fix that from our context
                apiResponse.comment.storyId = storyId;
                insertSingleCommentExtSync(apiResponse.comment);
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

    public void markStoryHashesStarred(Collection<String> hashes, boolean isStarred) {
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                ContentValues values = new ContentValues();
                values.put(DatabaseConstants.STORY_STARRED, isStarred);
                for (String hash : hashes) {
                    dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});
                }
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    public void setFeedsActive(Set<String> feedIds, boolean active) {
        synchronized (RW_MUTEX) {
            dbRW.beginTransaction();
            try {
                ContentValues values = new ContentValues();
                values.put(DatabaseConstants.FEED_ACTIVE, active);
                for (String feedId : feedIds) {
                    dbRW.update(DatabaseConstants.FEED_TABLE, values, DatabaseConstants.FEED_ID + " = ?", new String[]{feedId});
                }
                dbRW.setTransactionSuccessful();
            } finally {
                dbRW.endTransaction();
            }
        }
    }

    public void setFeedFetchPending(String feedId) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.FEED_FETCH_PENDING, true);
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.FEED_TABLE, values, DatabaseConstants.FEED_ID + " = ?", new String[]{feedId});}
    }

    public boolean isFeedSetFetchPending(FeedSet fs) {
        if (fs.getSingleFeed() != null) {
            String feedId = fs.getSingleFeed();
            Cursor c = dbRO.query(DatabaseConstants.FEED_TABLE, 
                                  new String[]{DatabaseConstants.FEED_FETCH_PENDING}, 
                                  DatabaseConstants.FEED_ID + " = ? AND " + DatabaseConstants.FEED_FETCH_PENDING + " = ?", 
                                  new String[]{feedId, "1"}, 
                                  null, null, null);
            try {
                if (c.getCount() > 0) return true;
            } finally {
                closeQuietly(c);
            }
        }
        return false;
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
            socialIds.addAll(Arrays.asList(story.friendUserIds));
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
            selection.append(TextUtils.join(",", fs.getMultipleSocialFeeds().keySet())).append(")");
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
            if(!f.active) continue;
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

    public void clearInfrequentSession() {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_INFREQUENT, false);
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.STORY_TABLE, values, null, null);}
    }

    public void enqueueAction(ReadingAction ra) {
        synchronized (RW_MUTEX) {dbRW.insertOrThrow(DatabaseConstants.ACTION_TABLE, null, ra.toContentValues());}
    }

    public Cursor getActions() {
        String q = "SELECT * FROM " + DatabaseConstants.ACTION_TABLE;
        return dbRO.rawQuery(q, null);
    }

    public void incrementActionTried(String actionId) {
        synchronized (RW_MUTEX) {
            String q = "UPDATE " + DatabaseConstants.ACTION_TABLE +
                       " SET " + DatabaseConstants.ACTION_TRIED + " = " + DatabaseConstants.ACTION_TRIED + " + 1" +
                       " WHERE " + DatabaseConstants.ACTION_ID + " = ?";
            dbRW.execSQL(q, new String[]{actionId});
        }
    }

    public int getUntriedActionCount() {
        String q = "SELECT * FROM " + DatabaseConstants.ACTION_TABLE + " WHERE " + DatabaseConstants.ACTION_TRIED + " < 1";
        Cursor c = dbRO.rawQuery(q, null);
        int result = c.getCount();
        c.close();
        return result;
    }

    public void clearAction(String actionId) {
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.ACTION_TABLE, DatabaseConstants.ACTION_ID + " = ?", new String[]{actionId});}
    }

    public void setStoryStarred(String hash, @Nullable List<String> userTags, boolean starred) {
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
                // if already stared, update user tags
                if (origState == starred && starred && userTags != null) {
                    ContentValues values = new ContentValues();
                    values.put(DatabaseConstants.STORY_USER_TAGS, TextUtils.join(",", userTags));
                    dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});
                    return;
                }
                // if there is nothing to be done, halt
                else if (origState == starred) {
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

    public void setStoryShared(String hash, boolean shared) {
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

        // the id to append to or remove from the shared list (the current user)
        String currentUser = PrefsUtils.getUserId(context);

        // append to set and update DB
        Set<String> newIds = new HashSet<String>(Arrays.asList(sharedUserIds));
        if (shared) {
            newIds.add(currentUser);
        } else {
            newIds.remove(currentUser);
        }
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
            // TODO: may not contain col?
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

    public Cursor getSocialFeedsCursor(CancellationSignal cancellationSignal) {
        return query(false, DatabaseConstants.SOCIALFEED_TABLE, null, null, null, null, null, "UPPER(" + DatabaseConstants.SOCIAL_FEED_TITLE + ") ASC", null, cancellationSignal);
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

    @Nullable
    public StarredCount getStarredFeedByTag(String tag) {
        Cursor c = dbRO.query(DatabaseConstants.STARREDCOUNTS_TABLE, null, DatabaseConstants.STARREDCOUNTS_TAG + " = ?", new String[] {tag}, null, null, null);
        StarredCount result = null;
        while (c.moveToNext()) {
            result = StarredCount.fromCursor(c);
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

    public Cursor getFoldersCursor(CancellationSignal cancellationSignal) {
        return query(false, DatabaseConstants.FOLDER_TABLE, null, null, null, null, null, null, null, cancellationSignal);
    }

    public Cursor getFeedsCursor(CancellationSignal cancellationSignal) {
        return query(false, DatabaseConstants.FEED_TABLE, null, null, null, null, null, "UPPER(" + DatabaseConstants.FEED_TITLE + ") ASC", null, cancellationSignal);
    }

    public Cursor getSavedStoryCountsCursor(CancellationSignal cancellationSignal) {
        return query(false, DatabaseConstants.STARREDCOUNTS_TABLE, null, null, null, null, null, null, null, cancellationSignal);
    }

    public Cursor getSavedSearchCursor(CancellationSignal cancellationSignal) {
        return query(false, DatabaseConstants.SAVED_SEARCH_TABLE, null, null, null, null,  null, null, null, cancellationSignal);
    }

    public Cursor getNotifyFocusStoriesCursor() {
        return rawQuery(DatabaseConstants.NOTIFY_FOCUS_STORY_QUERY, null, null);
    }

    public Cursor getNotifyUnreadStoriesCursor() {
        return rawQuery(DatabaseConstants.NOTIFY_UNREAD_STORY_QUERY, null, null);
    }

    public Set<String> getNotifyFeeds() {
        String q = "SELECT " + DatabaseConstants.FEED_ID + " FROM " + DatabaseConstants.FEED_TABLE +
                   " WHERE " + DatabaseConstants.FEED_NOTIFICATION_FILTER + " = '" + Feed.NOTIFY_FILTER_FOCUS + "'" +
                   " OR " + DatabaseConstants.FEED_NOTIFICATION_FILTER + " = '" + Feed.NOTIFY_FILTER_UNREAD + "'";
        Cursor c = dbRO.rawQuery(q, null);
        Set<String> feedIds = new HashSet<String>(c.getCount());
        while (c.moveToNext()) {
            String id = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.FEED_ID));
            if (id != null) {
                feedIds.add(id);
            }
        }
        c.close();
        return feedIds;
    }

    private Cursor getStoriesCursor(@Nullable FeedSet fs, CancellationSignal cancellationSignal) {
        StringBuilder q = new StringBuilder(DatabaseConstants.STORY_QUERY_BASE_0);

        if (fs != null && !TextUtils.isEmpty(fs.getSingleFeed())) {
            q.append(DatabaseConstants.STORY_FEED_ID);
            q.append(" = ");
            q.append(fs.getSingleFeed());
        } else {
            q.append(DatabaseConstants.FEED_ACTIVE);
            q.append(" = 1");
        }

        q.append(" ORDER BY ");
        q.append(DatabaseConstants.STORY_TIMESTAMP);
        q.append(" DESC LIMIT 20");
        return rawQuery(q.toString(), null, cancellationSignal);
    }

    public Cursor getActiveStoriesCursor(FeedSet fs, CancellationSignal cancellationSignal) {
        final StoryOrder order = PrefsUtils.getStoryOrder(context, fs);
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
        StringBuilder q = new StringBuilder(DatabaseConstants.SESSION_STORY_QUERY_BASE);
        
        if (fs.isAllRead()) {
            q.append(" ORDER BY ").append(DatabaseConstants.READ_STORY_ORDER);
        } else if (fs.isGlobalShared()) {
            q.append(" ORDER BY ").append(DatabaseConstants.SHARED_STORY_ORDER);
        } else if (fs.isAllSaved()) {
            q.append(" ORDER BY ").append(DatabaseConstants.getSavedStoriesSortOrder(order));
        } else {
            q.append(" ORDER BY ").append(DatabaseConstants.getStorySortOrder(order));
        }
        return rawQuery(q.toString(), null, cancellationSignal);
    }

    public void clearStorySession() {
        com.newsblur.util.Log.i(this, "reading session reset");
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
            sel.append(TextUtils.join(",", fs.getMultipleFeeds())).append(")");
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

        } else if (fs.isInfrequent()) {

            sel.append(" FROM " + DatabaseConstants.STORY_TABLE);
            sel.append(" WHERE (" + DatabaseConstants.STORY_INFREQUENT + " = 1)");
            DatabaseConstants.appendStorySelection(sel, selArgs, readFilter, stateFilter, fs.getSearchQuery());

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

    public void setSessionFeedSet(FeedSet fs) {
        if (fs == null) {
            synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.SYNC_METADATA_TABLE, DatabaseConstants.SYNC_METADATA_KEY + " = ?", new String[] {DatabaseConstants.SYNC_METADATA_KEY_SESSION_FEED_SET});}
        } else {
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.SYNC_METADATA_KEY, DatabaseConstants.SYNC_METADATA_KEY_SESSION_FEED_SET);
            values.put(DatabaseConstants.SYNC_METADATA_VALUE, fs.toCompactSerial());
            synchronized (RW_MUTEX) {dbRW.insertWithOnConflict(DatabaseConstants.SYNC_METADATA_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);}
        }
    }
        
    public FeedSet getSessionFeedSet() {
        FeedSet fs = null;
        Cursor c = dbRO.query(DatabaseConstants.SYNC_METADATA_TABLE, null, DatabaseConstants.SYNC_METADATA_KEY + " = ?", new String[] {DatabaseConstants.SYNC_METADATA_KEY_SESSION_FEED_SET}, null, null, null, null);
        if (c.getCount() < 1) return null;
        c.moveToFirst();
        fs = FeedSet.fromCompactSerial(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.SYNC_METADATA_VALUE)));
        closeQuietly(c);
        return fs;
    }

    public boolean isFeedSetReady(FeedSet fs) {
        return fs.equals(getSessionFeedSet());
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
        classifier.feedId = feedId;
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

    /**
     * Insert brand new comment for which we do not yet have a server-assigned ID.  This comment
     * will show up in the UI with reduced functionality until the server gets back to us with
     * an ID at which time the placeholder will be removed.
     */
    public void insertCommentPlaceholder(String storyId, String feedId, String commentText) {
        String userId = PrefsUtils.getUserId(context);
        Comment comment = new Comment();
        comment.isPlaceholder = true;
        comment.id = Comment.PLACEHOLDER_COMMENT_ID + storyId + userId;
        comment.storyId = storyId;
        comment.userId = userId;
        comment.commentText = commentText;
        comment.byFriend = true;
        if (TextUtils.isEmpty(commentText)) {
            comment.isPseudo = true;
        }
        synchronized (RW_MUTEX) {
            // in order to make this method idempotent (so it can be attempted before, during, or after
            // the real comment is done, we have to check for a real one
            if (getComment(storyId, userId) != null) {
                com.newsblur.util.Log.i(this.getClass().getName(), "electing not to insert placeholder comment over live one");
                return;
            }
            dbRW.insertWithOnConflict(DatabaseConstants.COMMENT_TABLE, null, comment.getValues(), SQLiteDatabase.CONFLICT_REPLACE);
        }
    }

    public void editReply(String replyId, String replyText) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.REPLY_TEXT, replyText);
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.REPLY_TABLE, values, DatabaseConstants.REPLY_ID + " = ?", new String[]{replyId});}
    }

    public void deleteReply(String replyId) {   
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.REPLY_TABLE, DatabaseConstants.REPLY_ID + " = ?", new String[]{replyId});}
    }

    public void clearSelfComments(String storyId) {
        String userId = PrefsUtils.getUserId(context);
        synchronized (RW_MUTEX) {dbRW.delete(DatabaseConstants.COMMENT_TABLE, 
                                             DatabaseConstants.COMMENT_STORYID + " = ? AND " + DatabaseConstants.COMMENT_USERID + " = ?", 
                                             new String[]{storyId, userId});}
    }

    public void setCommentLiked(String storyId, String userId, String feedId, boolean liked) {
        // get a fresh copy of the story from the DB so we can append to the shared ID set
        Cursor c = dbRO.query(DatabaseConstants.COMMENT_TABLE, 
                              null, 
                              DatabaseConstants.COMMENT_STORYID + " = ? AND " + DatabaseConstants.COMMENT_USERID + " = ?", 
                              new String[]{storyId, userId}, 
                              null, null, null);
        if ((c == null)||(c.getCount() < 1)) {
            Log.w(this.getClass().getName(), "comment removed before finishing mark-liked");
            closeQuietly(c);
            return;
        }
        c.moveToFirst();
        Comment comment = Comment.fromCursor(c);
        closeQuietly(c);

        // the new id to append/remove from the liking list (the current user)
        String currentUser = PrefsUtils.getUserId(context);

        // append to set and update DB
        Set<String> newIds = new HashSet<String>(Arrays.asList(comment.likingUsers));
        if (liked) {
            newIds.add(currentUser);
        } else {
            newIds.remove(currentUser);
        }
        ContentValues values = new ContentValues();
		values.put(DatabaseConstants.COMMENT_LIKING_USERS, TextUtils.join(",", newIds));
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.COMMENT_TABLE, values, DatabaseConstants.COMMENT_ID + " = ?", new String[]{comment.id});}
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

    public void insertReplyPlaceholder(String storyId, String feedId, String commentUserId, String replyText) {
        // get a fresh copy of the comment so we can discover the ID
        Cursor c = dbRO.query(DatabaseConstants.COMMENT_TABLE, 
                              null, 
                              DatabaseConstants.COMMENT_STORYID + " = ? AND " + DatabaseConstants.COMMENT_USERID + " = ?", 
                              new String[]{storyId, commentUserId}, 
                              null, null, null);
        if ((c == null)||(c.getCount() < 1)) {
            com.newsblur.util.Log.w(this, "comment removed before reply could be processed");
            closeQuietly(c);
            return;
        }
        c.moveToFirst();
        Comment comment = Comment.fromCursor(c);
        closeQuietly(c);

        Reply reply = new Reply();
        reply.commentId = comment.id;
        reply.text = replyText;
        reply.userId = PrefsUtils.getUserId(context);
        reply.date = new Date();
        reply.id = Reply.PLACEHOLDER_COMMENT_ID + storyId + comment.id + reply.userId;
        synchronized (RW_MUTEX) {dbRW.insertWithOnConflict(DatabaseConstants.REPLY_TABLE, null, reply.getValues(), SQLiteDatabase.CONFLICT_REPLACE);}
    }

    public void putStoryDismissed(String storyHash) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.NOTIFY_DISMISS_STORY_HASH, storyHash);
        values.put(DatabaseConstants.NOTIFY_DISMISS_TIME, Calendar.getInstance().getTime().getTime());
        synchronized (RW_MUTEX) {dbRW.insertOrThrow(DatabaseConstants.NOTIFY_DISMISS_TABLE, null, values);}
    }

    public boolean isStoryDismissed(String storyHash) {
        String[] selArgs = new String[] {storyHash};
        String selection = DatabaseConstants.NOTIFY_DISMISS_STORY_HASH + " = ?";
        Cursor c = dbRO.query(DatabaseConstants.NOTIFY_DISMISS_TABLE, null, selection, selArgs, null, null, null);
        boolean result = (c.getCount() > 0);
        closeQuietly(c);
        return result;
    }

    public void cleanupDismissals() {
        Calendar cutoffDate = Calendar.getInstance();
        cutoffDate.add(Calendar.MONTH, -1);
        synchronized (RW_MUTEX) {
            int count = dbRW.delete(DatabaseConstants.NOTIFY_DISMISS_TABLE, 
                        DatabaseConstants.NOTIFY_DISMISS_TIME + " < ?",
                        new String[]{Long.toString(cutoffDate.getTime().getTime())});
            com.newsblur.util.Log.d(this.getClass().getName(), "cleaned up dismissals: " + count);
        }
    }

    private void putFeedTagsExtSync(String feedId, Collection<String> tags) {
        dbRW.delete(DatabaseConstants.FEED_TAGS_TABLE,
                    DatabaseConstants.FEED_TAGS_FEEDID + " = ?",
                    new String[]{feedId}
                   );
        List<ContentValues> valuesList = new ArrayList<ContentValues>(tags.size());
        for (String tag : tags) {
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.FEED_TAGS_FEEDID, feedId);
            values.put(DatabaseConstants.FEED_TAGS_TAG, tag);
            valuesList.add(values);
        }
        bulkInsertValuesExtSync(DatabaseConstants.FEED_TAGS_TABLE, valuesList);
    }

    public List<String> getTagsForFeed(String feedId) {
        Cursor c = dbRO.query(DatabaseConstants.FEED_TAGS_TABLE, 
                              new String[]{DatabaseConstants.FEED_TAGS_TAG}, 
                              DatabaseConstants.FEED_TAGS_FEEDID + " = ?", 
                              new String[]{feedId}, 
                              null, 
                              null, 
                              DatabaseConstants.FEED_TAGS_TAG + " ASC"
                             );
        List<String> result = new ArrayList<String>(c.getCount());
        while (c.moveToNext()) {
            result.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.FEED_TAGS_TAG)));
        }
        closeQuietly(c);
        return result;
    }
        
    private void putFeedAuthorsExtSync(String feedId, Collection<String> authors) {
        dbRW.delete(DatabaseConstants.FEED_AUTHORS_TABLE,
                    DatabaseConstants.FEED_AUTHORS_FEEDID + " = ?",
                    new String[]{feedId}
                   );
        List<ContentValues> valuesList = new ArrayList<ContentValues>(authors.size());
        for (String author : authors) {
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.FEED_AUTHORS_FEEDID, feedId);
            values.put(DatabaseConstants.FEED_AUTHORS_AUTHOR, author);
            valuesList.add(values);
        }
        bulkInsertValuesExtSync(DatabaseConstants.FEED_AUTHORS_TABLE, valuesList);
    }

    public List<String> getAuthorsForFeed(String feedId) {
        Cursor c = dbRO.query(DatabaseConstants.FEED_AUTHORS_TABLE, 
                              new String[]{DatabaseConstants.FEED_AUTHORS_AUTHOR}, 
                              DatabaseConstants.FEED_AUTHORS_FEEDID + " = ?", 
                              new String[]{feedId}, 
                              null, 
                              null, 
                              DatabaseConstants.FEED_AUTHORS_AUTHOR + " ASC"
                             );
        List<String> result = new ArrayList<String>(c.getCount());
        while (c.moveToNext()) {
            result.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.FEED_AUTHORS_AUTHOR)));
        }
        closeQuietly(c);
        return result;
    }

    public void renameFeed(String feedId, String newFeedName) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.FEED_TITLE, newFeedName);
        synchronized (RW_MUTEX) {dbRW.update(DatabaseConstants.FEED_TABLE, values, DatabaseConstants.FEED_ID + " = ?", new String[]{feedId});}
    }

    public static void closeQuietly(Cursor c) {
        if (c == null) return;
        try {c.close();} catch (Exception e) {;}
    }

    public void sendSyncUpdate(int updateType) {
        UIUtils.syncUpdateStatus(context, updateType);
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

    public FeedSet feedSetFromFolderName(String folderName) {
        return FeedSet.folder(folderName, getFeedIdsRecursive(folderName));
    }

    private Set<String> getFeedIdsRecursive(String folderName) {
        Folder folder = getFolder(folderName);
        if (folder == null) return emptySet();
        Set<String> feedIds = new HashSet<>(folder.feedIds);
        for (String child : folder.children) feedIds.addAll(getFeedIdsRecursive(child));
        return feedIds;
    }
}
