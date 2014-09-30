package com.newsblur.database;

import android.content.ContentValues;
import android.content.Context;
import android.content.Loader;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.text.TextUtils;
import android.util.Log;

import com.newsblur.domain.Classifier;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Feed;
import com.newsblur.domain.FeedResult;
import com.newsblur.domain.Reply;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadingAction;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;

import java.util.ArrayList;
import java.util.HashSet;
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

    private Context context;
    private BlurDatabase dbWrapper;
    private SQLiteDatabase dbRO;
    private SQLiteDatabase dbRW;

    public BlurDatabaseHelper(Context context) {
        this.context = context;
        dbWrapper = new BlurDatabase(context);
        dbRO = dbWrapper.getRO();
        dbRW = dbWrapper.getRW();
    }

    public void close() {
        dbWrapper.close();
    }

    public boolean isOpen() {
        return dbRW.isOpen();
    }

    private List<String> getAllFeeds() {
        String q1 = "SELECT " + DatabaseConstants.FEED_ID +
                    " FROM " + DatabaseConstants.FEED_TABLE;
        Cursor c = dbRO.rawQuery(q1, null);
        List<String> feedIds = new ArrayList<String>(c.getCount());
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

    public void cleanupStories(boolean keepOldStories) {
        for (String feedId : getAllFeeds()) {
            String q = "DELETE FROM " + DatabaseConstants.STORY_TABLE + 
                       " WHERE " + DatabaseConstants.STORY_ID + " IN " +
                       "( SELECT " + DatabaseConstants.STORY_ID + " FROM " + DatabaseConstants.STORY_TABLE +
                       " WHERE " + DatabaseConstants.STORY_READ + " = 1" +
                       " AND " + DatabaseConstants.STORY_FEED_ID + " = " + feedId +
                       " ORDER BY " + DatabaseConstants.STORY_TIMESTAMP + " DESC" +
                       " LIMIT -1 OFFSET " + (keepOldStories ? AppConstants.MAX_READ_STORIES_STORED : 0) +
                       ")";
            dbRW.execSQL(q);
        }
    }

    public void cleanupActions() {
        // TODO: write me, use me
    }

    public void cleanupFeedsFolders() {
        dbRW.delete(DatabaseConstants.FEED_TABLE, null, null);
        dbRW.delete(DatabaseConstants.FOLDER_TABLE, null, null);
        dbRW.delete(DatabaseConstants.FEED_FOLDER_MAP_TABLE, null, null);
    }

    private void bulkInsertValues(String table, List<ContentValues> valuesList) {
        if (valuesList.size() < 1) return;
        dbRW.beginTransaction();
        try {
            for(ContentValues values: valuesList) {
                dbRW.insertWithOnConflict(table, null, values, SQLiteDatabase.CONFLICT_REPLACE);
            }
            dbRW.setTransactionSuccessful();
        } finally {
            dbRW.endTransaction();
        }
    }

    public void insertFeedsFolders(List<ContentValues> feedValues,
                                   List<ContentValues> folderValues,
                                   List<ContentValues> ffmValues,
                                   List<ContentValues> socialFeedValues) {
        bulkInsertValues(DatabaseConstants.FEED_TABLE, feedValues);
        bulkInsertValues(DatabaseConstants.FOLDER_TABLE, folderValues);
        bulkInsertValues(DatabaseConstants.FEED_FOLDER_MAP_TABLE, ffmValues);
        bulkInsertValues(DatabaseConstants.SOCIALFEED_TABLE, socialFeedValues);
    }

    public void updateStarredStoriesCount(int count) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STARRED_STORY_COUNT_COUNT, count);
        // this DB just has one row and one column.  blow it away and replace it.
        dbRW.delete(DatabaseConstants.STARRED_STORY_COUNT_TABLE, null, null);
        dbRW.insert(DatabaseConstants.STARRED_STORY_COUNT_TABLE, null, values);
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

    public List<String> getUnreadStoryHashes() {
        String q = "SELECT " + DatabaseConstants.STORY_HASH + 
                   " FROM " + DatabaseConstants.STORY_TABLE +
                   " WHERE " + DatabaseConstants.STORY_READ + " = 0" ;
        Cursor c = dbRO.rawQuery(q, null);
        List<String> hashes = new ArrayList<String>(c.getCount());
        while (c.moveToNext()) {
           hashes.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_HASH)));
        }
        c.close();
        return hashes;
    }

    public void insertStories(StoriesResponse apiResponse) {
        // to insert classifiers, we need to determine the feed ID of the stories in this
        // response, so sniff one out.
        String impliedFeedId = null;

        // handle users
        if (apiResponse.users != null) {
            List<ContentValues> userValues = new ArrayList<ContentValues>(apiResponse.users.length);
            for (UserProfile user : apiResponse.users) {
                userValues.add(user.getValues());
            }
            bulkInsertValues(DatabaseConstants.USER_TABLE, userValues);
        }

        // handle supplemental feed data that may have been included (usually in social requests)
        if (apiResponse.feeds != null) {
            List<ContentValues> feedValues = new ArrayList<ContentValues>(apiResponse.feeds.size());
            for (Feed feed : apiResponse.feeds) {
                feedValues.add(feed.getValues());
            }
            bulkInsertValues(DatabaseConstants.FEED_TABLE, feedValues);
        }

        // handle story content
        List<ContentValues> storyValues = new ArrayList<ContentValues>(apiResponse.stories.length);
        List<ContentValues> socialStoryValues = new ArrayList<ContentValues>();
        for (Story story : apiResponse.stories) {
            ContentValues values = story.getValues();
            // the basic columns are fine for the stories table
            storyValues.add(values);
            // if a story was shared by a user, also insert it into the social table under their userid, too
            for (String sharedUserId : story.sharedUserIds) {
                ContentValues socialValues = new ContentValues();
                socialValues.put(DatabaseConstants.SOCIALFEED_STORY_USER_ID, sharedUserId);
                socialValues.put(DatabaseConstants.SOCIALFEED_STORY_STORYID, values.getAsString(DatabaseConstants.STORY_ID));
                socialStoryValues.add(socialValues);
            }
            impliedFeedId = story.feedId;
        }
        bulkInsertValues(DatabaseConstants.STORY_TABLE, storyValues);
        bulkInsertValues(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE, socialStoryValues);

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
                bulkInsertValues(DatabaseConstants.CLASSIFIER_TABLE, classifierValues);
            }
        }

        // handle comments
        List<ContentValues> commentValues = new ArrayList<ContentValues>();
        List<ContentValues> replyValues = new ArrayList<ContentValues>();
        for (Story story : apiResponse.stories) {
            for (Comment comment : story.publicComments) {
                comment.storyId = story.id;
                comment.id = TextUtils.concat(story.id, story.feedId, comment.userId).toString();
                commentValues.add(comment.getValues());
                for (Reply reply : comment.replies) {
                    reply.commentId = comment.id;
                    replyValues.add(reply.getValues());
                }
            }
            for (Comment comment : story.friendsComments) {
                comment.storyId = story.id;
                comment.id = TextUtils.concat(story.id, story.feedId, comment.userId).toString();
                commentValues.add(comment.getValues());
                for (Reply reply : comment.replies) {
                    reply.commentId = comment.id;
                    replyValues.add(reply.getValues());
                }
            }
        }
        bulkInsertValues(DatabaseConstants.COMMENT_TABLE, commentValues);
        bulkInsertValues(DatabaseConstants.REPLY_TABLE, replyValues);
    }

    public Set<String> getFeedsForFolder(String folderName) {
        Set<String> feedIds = new HashSet<String>();
        String q = "SELECT " + DatabaseConstants.FEED_FOLDER_FEED_ID + 
                   " FROM " + DatabaseConstants.FEED_FOLDER_MAP_TABLE +
                   " WHERE " + DatabaseConstants.FEED_FOLDER_FOLDER_NAME + " = ?" ;
        Cursor c = dbRO.rawQuery(q, new String[]{folderName});
        while (c.moveToNext()) {
           feedIds.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.FEED_FOLDER_FEED_ID)));
        }
        c.close();
        return feedIds;
    }

    public void markStoryHashesRead(List<String> hashes) {
        // NOTE: attempting to wrap these updates in a transaction for speed makes them silently fail
        for (String hash : hashes) {
            setStoryReadState(hash, true);
        }
    }

    public void setStoryReadState(String hash, boolean read) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_READ, read);
        values.put(DatabaseConstants.STORY_READ_THIS_SESSION, read);
        dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});
    }

    /**
     * Marks a story (un)read and also adjusts unread counts for it.
     */
    public void setStoryReadState(Story story, boolean read) {
        setStoryReadState(story.storyHash, read);
        // non-social feed count
        refreshFeedCounts(FeedSet.singleFeed(story.feedId));
        // social feed counts
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
            refreshFeedCounts(FeedSet.multipleSocialFeeds(socialIds));
        }
    }

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
        dbRW.update(DatabaseConstants.STORY_TABLE, values, conjoinSelections(feedSelection, rangeSelection), null);

        refreshFeedCounts(fs);
    }

    /**
     * Refreshes the counts in the feeds/socialfeeds tables by counting stories in the story table.
     */
    public void refreshFeedCounts(FeedSet fs) {
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
            values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, getUnreadCount(singleFs, StateFilter.NEG));
            values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, getUnreadCount(singleFs, StateFilter.NEUT));
            values.put(DatabaseConstants.FEED_POSITIVE_COUNT, getUnreadCount(singleFs, StateFilter.BEST));
            dbRW.update(DatabaseConstants.FEED_TABLE, values, DatabaseConstants.FEED_ID + " = ?", new String[]{feedId});
        }

        for (String socialId : socialFeedIds) {
            FeedSet singleFs = FeedSet.singleSocialFeed(socialId, "");
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, getUnreadCount(singleFs, StateFilter.NEG));
            values.put(DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, getUnreadCount(singleFs, StateFilter.NEUT));
            values.put(DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT, getUnreadCount(singleFs, StateFilter.BEST));
            dbRW.update(DatabaseConstants.SOCIALFEED_TABLE, values, DatabaseConstants.SOCIAL_FEED_ID + " = ?", new String[]{socialId});
        }
    }

    public int getUnreadCount(FeedSet fs, StateFilter stateFilter) {
        Cursor c = getStoriesCursor(fs, stateFilter, ReadFilter.PURE_UNREAD, null);
        int count = c.getCount();
        c.close();
        return count;
    }

    public void enqueueAction(ReadingAction ra) {
        dbRW.insertOrThrow(DatabaseConstants.ACTION_TABLE, null, ra.toContentValues());
    }

    public Cursor getActions(boolean includeDone) {
        String q = "SELECT * FROM " + DatabaseConstants.ACTION_TABLE;
        return dbRO.rawQuery(q, null);
    }

    public void clearAction(String actionId) {
        dbRW.delete(DatabaseConstants.ACTION_TABLE, DatabaseConstants.ACTION_ID + " = ?", new String[]{actionId});
    }

    public Cursor getStory(String hash) {
        String q = "SELECT * FROM " + DatabaseConstants.STORY_TABLE +
                   " WHERE " + DatabaseConstants.STORY_HASH + " = ?";
        return dbRO.rawQuery(q, new String[]{hash});
    }

    public void setStoryStarred(String hash, boolean starred) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_STARRED, starred);
        dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});
    }

    /**
     * Tags all saved stories with the reading session flag so they don't disappear if unsaved.
     */
    public void markSavedReadingSession() {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_READ_THIS_SESSION, true);
        dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_STARRED + " = 1", null);
    }

    /**
     * Clears the read_this_session flag for all stories so they won't be displayed.
     */
    public void clearReadingSession() {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STORY_READ_THIS_SESSION, false);
        dbRW.update(DatabaseConstants.STORY_TABLE, values, null, null);
    }

    public Loader<Cursor> getStoriesLoader(final FeedSet fs, final StateFilter stateFilter) {
        return new QueryCursorLoader(context) {
            protected Cursor createCursor() {return getStoriesCursor(fs, stateFilter);}
        };
    }

    public Cursor getStoriesCursor(FeedSet fs, StateFilter stateFilter) {
        ReadFilter readFilter = PrefsUtils.getReadFilter(context, fs);
        StoryOrder order = PrefsUtils.getStoryOrder(context, fs);
        return getStoriesCursor(fs, stateFilter, readFilter, order);
    }

    public Cursor getStoriesCursor(FeedSet fs, StateFilter stateFilter, ReadFilter readFilter, StoryOrder order) {

        if (fs.getSingleFeed() != null) {

            StringBuilder q = new StringBuilder("SELECT ");
            q.append(TextUtils.join(",", DatabaseConstants.STORY_COLUMNS));
            q.append(" FROM " + DatabaseConstants.STORY_TABLE);
            q.append(" WHERE " + DatabaseConstants.STORY_FEED_ID + " = ?");
            DatabaseConstants.appendStorySelectionGroupOrder(q, readFilter, order, stateFilter, null);
            return dbRO.rawQuery(q.toString(), new String[]{fs.getSingleFeed()});

        } else if (fs.getMultipleFeeds() != null) {

            StringBuilder q = new StringBuilder(DatabaseConstants.MULTIFEED_STORIES_QUERY_BASE);
            q.append(" FROM " + DatabaseConstants.STORY_TABLE);
            q.append(DatabaseConstants.JOIN_FEEDS_ON_STORIES);
            q.append(" WHERE " + DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_FEED_ID + " IN ( ");
            q.append(TextUtils.join(",", fs.getMultipleFeeds()) + ")");
            DatabaseConstants.appendStorySelectionGroupOrder(q, readFilter, order, stateFilter, null);
            return dbRO.rawQuery(q.toString(), null);

        } else if (fs.getSingleSocialFeed() != null) {

            StringBuilder q = new StringBuilder(DatabaseConstants.MULTIFEED_STORIES_QUERY_BASE);
            q.append(" FROM " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE);
            q.append(DatabaseConstants.JOIN_STORIES_ON_SOCIALFEED_MAP);
            q.append(DatabaseConstants.JOIN_FEEDS_ON_STORIES);
            q.append(" WHERE " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE + "." + DatabaseConstants.SOCIALFEED_STORY_USER_ID + " = ? ");
            DatabaseConstants.appendStorySelectionGroupOrder(q, readFilter, order, stateFilter, null);
            return dbRO.rawQuery(q.toString(), new String[]{fs.getSingleSocialFeed().getKey()});

        } else if (fs.isAllNormal()) {

            StringBuilder q = new StringBuilder(DatabaseConstants.MULTIFEED_STORIES_QUERY_BASE);
            q.append(" FROM " + DatabaseConstants.STORY_TABLE);
            q.append(DatabaseConstants.JOIN_FEEDS_ON_STORIES);
            q.append(" WHERE 1");
            DatabaseConstants.appendStorySelectionGroupOrder(q, readFilter, order, stateFilter, null);
            return dbRO.rawQuery(q.toString(), null);

        } else if (fs.isAllSocial()) {

            StringBuilder q = new StringBuilder(DatabaseConstants.MULTIFEED_STORIES_QUERY_BASE);
            q.append(" FROM " + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE);
            q.append(DatabaseConstants.JOIN_STORIES_ON_SOCIALFEED_MAP);
            q.append(DatabaseConstants.JOIN_FEEDS_ON_STORIES);
            DatabaseConstants.appendStorySelectionGroupOrder(q, readFilter, order, stateFilter, DatabaseConstants.STORY_TABLE + "." + DatabaseConstants.STORY_ID);
            return dbRO.rawQuery(q.toString(), null);

        } else if (fs.isAllSaved()) {

            StringBuilder q = new StringBuilder(DatabaseConstants.MULTIFEED_STORIES_QUERY_BASE);
            q.append(" FROM " + DatabaseConstants.STORY_TABLE);
            q.append(DatabaseConstants.JOIN_FEEDS_ON_STORIES);
            q.append(" WHERE ((" + DatabaseConstants.STORY_STARRED + " = 1)");
            q.append(" OR (" + DatabaseConstants.STORY_READ_THIS_SESSION + " = 1))");
            q.append(" ORDER BY " + DatabaseConstants.STARRED_STORY_ORDER);
            return dbRO.rawQuery(q.toString(), null);

        } else {
            throw new IllegalStateException("Asked to get stories for FeedSet of unknown type.");
        }
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

}
