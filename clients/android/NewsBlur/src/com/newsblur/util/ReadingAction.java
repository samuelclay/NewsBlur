package com.newsblur.util;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.APIManager;

import java.util.HashSet;
import java.util.Set;

public class ReadingAction {

    private enum ActionType {
        MARK_READ,
        MARK_UNREAD,
        SAVE,
        UNSAVE,
        SHARE,
        REPLY,
        LIKE_COMMENT,
        UNLIKE_COMMENT
    };

    private ActionType type;
    private String storyHash;
    private FeedSet feedSet;
    private Long olderThan;
    private Long newerThan;
    private String storyId;
    private String feedId;
    private String sourceUserId;
    private String commentText;
    private String commentId;

    private ReadingAction() {
        ; // must use helpers
    }

    public static ReadingAction markStoryRead(String hash) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.MARK_READ;
        ra.storyHash = hash;
        return ra;
    }

    public static ReadingAction markStoryUnread(String hash) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.MARK_UNREAD;
        ra.storyHash = hash;
        return ra;
    }

    public static ReadingAction saveStory(String hash) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.SAVE;
        ra.storyHash = hash;
        return ra;
    }

    public static ReadingAction unsaveStory(String hash) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNSAVE;
        ra.storyHash = hash;
        return ra;
    }

    public static ReadingAction markFeedRead(FeedSet fs, Long olderThan, Long newerThan) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.MARK_READ;
        ra.feedSet = fs;
        ra.olderThan = olderThan;
        ra.newerThan = newerThan;
        return ra;
    }

    public static ReadingAction shareStory(String hash, String storyId, String feedId, String sourceUserId, String commentText) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.SHARE;
        ra.storyHash = hash;
        ra.storyId = storyId;
        ra.feedId = feedId;
        ra.sourceUserId = sourceUserId;
        ra.commentText = commentText;
        return ra;
    }

    public static ReadingAction likeComment(String storyId, String commentId, String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.LIKE_COMMENT;
        ra.storyId = storyId;
        ra.commentId = commentId;
        ra.feedId = feedId;
        return ra;
    }

    public static ReadingAction unlikeComment(String storyId, String commentId, String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNLIKE_COMMENT;
        ra.storyId = storyId;
        ra.commentId = commentId;
        ra.feedId = feedId;
        return ra;
    }

	public ContentValues toContentValues() {
		ContentValues values = new ContentValues();
        values.put(DatabaseConstants.ACTION_TIME, System.currentTimeMillis());
        switch (type) {

            case MARK_READ:
                values.put(DatabaseConstants.ACTION_MARK_READ, 1);
                if (storyHash != null) {
                    values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                } else if (feedSet != null) {
                    values.put(DatabaseConstants.ACTION_FEED_ID, feedSet.toCompactSerial());
                    if (olderThan != null) values.put(DatabaseConstants.ACTION_INCLUDE_OLDER, olderThan);
                    if (newerThan != null) values.put(DatabaseConstants.ACTION_INCLUDE_NEWER, newerThan);
                }
                break;
                
            case MARK_UNREAD:
                values.put(DatabaseConstants.ACTION_MARK_UNREAD, 1);
                if (storyHash != null) {
                    values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                }
                break;

            case SAVE:
                values.put(DatabaseConstants.ACTION_SAVE, 1);
                values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                break;

            case UNSAVE:
                values.put(DatabaseConstants.ACTION_UNSAVE, 1);
                values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                break;

            case SHARE:
                values.put(DatabaseConstants.ACTION_SHARE, 1);
                values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_SOURCE_USER_ID, sourceUserId);
                values.put(DatabaseConstants.ACTION_COMMENT, commentText);
                break;

            case LIKE_COMMENT:
                values.put(DatabaseConstants.ACTION_LIKE_COMMENT, 1);
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_COMMENT_ID, commentId);
                break;

            case UNLIKE_COMMENT:
                values.put(DatabaseConstants.ACTION_UNLIKE_COMMENT, 1);
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_COMMENT_ID, commentId);
                break;

            default:
                throw new IllegalStateException("cannot serialise uknown type of action.");

        }

		return values;
	}

	public static ReadingAction fromCursor(Cursor c) {
		ReadingAction ra = new ReadingAction();
        if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_MARK_READ)) == 1) {
            ra.type = ActionType.MARK_READ;
            String hash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
            String feedIds = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            Long includeOlder = DatabaseConstants.nullIfZero(c.getLong(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_INCLUDE_OLDER)));
            Long includeNewer = DatabaseConstants.nullIfZero(c.getLong(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_INCLUDE_NEWER)));
            if (hash != null) {
                ra.storyHash = hash;
            } else if (feedIds != null) {
                ra.feedSet = FeedSet.fromCompactSerial(feedIds);
                ra.olderThan = includeOlder;
                ra.newerThan = includeNewer;
            } else {
                throw new IllegalStateException("cannot deserialise uknown type of action.");
            }
        } else if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_MARK_UNREAD)) == 1) {
            ra.type = ActionType.MARK_UNREAD;
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
        } else if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_SAVE)) == 1) {
            ra.type = ActionType.SAVE;
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
        } else if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_UNSAVE)) == 1) {
            ra.type = ActionType.UNSAVE;
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
        } else if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_SHARE)) == 1) {
            ra.type = ActionType.SHARE;
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.sourceUserId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_SOURCE_USER_ID));
            ra.commentText = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT));
        } else if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_LIKE_COMMENT)) == 1) {
            ra.type = ActionType.LIKE_COMMENT;
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.commentId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_ID));
        } else if (c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_UNLIKE_COMMENT)) == 1) {
            ra.type = ActionType.UNLIKE_COMMENT;
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.commentId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_ID));
        } else {
            throw new IllegalStateException("cannot deserialise uknown type of action.");
        }
		return ra;
	}

    /**
     * Execute this action remotely via the API.
     */
    public NewsBlurResponse doRemote(APIManager apiManager) {
        switch (type) {

            case MARK_READ:
                if (storyHash != null) {
                    return apiManager.markStoryAsRead(storyHash);
                } else if (feedSet != null) {
                    return apiManager.markFeedsAsRead(feedSet, olderThan, newerThan);
                }
                break;
                
            case MARK_UNREAD:
                return apiManager.markStoryHashUnread(storyHash);

            case SAVE:
                return apiManager.markStoryAsStarred(storyHash);

            case UNSAVE:
                return apiManager.markStoryAsUnstarred(storyHash);

            case SHARE:
                return apiManager.shareStory(storyId, feedId, commentText, sourceUserId);

            case LIKE_COMMENT:
                return apiManager.favouriteComment(storyId, commentId, feedId);

            case UNLIKE_COMMENT:
                return apiManager.unFavouriteComment(storyId, commentId, feedId);

            default:

        }

        throw new IllegalStateException("cannot execute uknown type of action.");
    }

    /**
     * Excecute this action on the local DB. These must be idempotent.
     */
    public void doLocal(BlurDatabaseHelper dbHelper) {
        switch (type) {

            case MARK_READ:
                if (storyHash != null) {
                    dbHelper.setStoryReadState(storyHash, true);
                } else if (feedSet != null) {
                    dbHelper.markStoriesRead(feedSet, olderThan, newerThan);
                }
                break;
                
            case MARK_UNREAD:
                dbHelper.setStoryReadState(storyHash, false);
                break;

            case SAVE:
                dbHelper.setStoryStarred(storyHash, true);
                break;

            case UNSAVE:
                dbHelper.setStoryStarred(storyHash, false);
                break;

            case SHARE:
                dbHelper.setStoryShared(storyHash);
                if (!TextUtils.isEmpty(commentText)) {
                    dbHelper.insertUpdateComment(storyId, feedId, commentText);
                }
                break;

            case LIKE_COMMENT:
                // TODO
                break;

            case UNLIKE_COMMENT:
                // TODO
                break;

            default:
                // not all actions have these, which is fine
        }
    }

}
