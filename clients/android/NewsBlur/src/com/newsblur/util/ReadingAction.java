package com.newsblur.util;

import android.content.ContentValues;
import android.database.Cursor;

import java.io.Serializable;

import com.newsblur.activity.NbActivity;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.APIManager;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@SuppressWarnings("serial")
public class ReadingAction implements Serializable {

    private static final long serialVersionUID = 0L;

    private enum ActionType {
        MARK_READ,
        MARK_UNREAD,
        SAVE,
        UNSAVE,
        SHARE,
        UNSHARE,
        REPLY,
        EDIT_REPLY,
        DELETE_REPLY,
        LIKE_COMMENT,
        UNLIKE_COMMENT,
        MUTE_FEEDS,
        UNMUTE_FEEDS,
        SET_NOTIFY
    };

    private final long time;
    private final int tried;
    private ActionType type;
    private String storyHash;
    private FeedSet feedSet;
    private Long olderThan;
    private Long newerThan;
    private String storyId;
    private String feedId;
    private String sourceUserId;
    private String commentReplyText; // used for both comments and replies
    private String commentUserId;
    private String replyId;
    private String notifyFilter;
    private List<String> notifyTypes;

    // For mute/unmute the API call is always the active feed IDs.
    // We need the feed Ids being modified for the local call.
    private Set<String> activeFeedIds;
    private Set<String> modifiedFeedIds;

    private ReadingAction() {
        // note: private - must use helpers
        this(System.currentTimeMillis(), 0);
    }

    private ReadingAction(long time, int tried) {
        // note: private - must use helpers
        this.time = time;
        this.tried = tried;
    }
    
    public int getTried() {
        return tried;
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

    public static ReadingAction shareStory(String hash, String storyId, String feedId, String sourceUserId, String commentReplyText) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.SHARE;
        ra.storyHash = hash;
        ra.storyId = storyId;
        ra.feedId = feedId;
        ra.sourceUserId = sourceUserId;
        ra.commentReplyText = commentReplyText;
        return ra;
    }

    public static ReadingAction unshareStory(String hash, String storyId, String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNSHARE;
        ra.storyHash = hash;
        ra.storyId = storyId;
        ra.feedId = feedId;
        return ra;
    }

    public static ReadingAction likeComment(String storyId, String commentUserId, String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.LIKE_COMMENT;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        return ra;
    }

    public static ReadingAction unlikeComment(String storyId, String commentUserId, String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNLIKE_COMMENT;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        return ra;
    }

    public static ReadingAction replyToComment(String storyId, String feedId, String commentUserId, String commentReplyText) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.REPLY;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        ra.commentReplyText = commentReplyText;
        return ra;
    }

    public static ReadingAction updateReply(String storyId, String feedId, String commentUserId, String replyId, String commentReplyText) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.EDIT_REPLY;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        ra.commentReplyText = commentReplyText;
        ra.replyId = replyId;
        return ra;
    }

    public static ReadingAction deleteReply(String storyId, String feedId, String commentUserId, String replyId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.DELETE_REPLY;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        ra.replyId = replyId;
        return ra;
    }

    public static ReadingAction muteFeeds(Set<String> activeFeedIds, Set<String> modifiedFeedIds) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.MUTE_FEEDS;
        ra.activeFeedIds = activeFeedIds;
        ra.modifiedFeedIds = modifiedFeedIds;
        return ra;
    }

    public static ReadingAction unmuteFeeds(Set<String> activeFeedIds, Set<String> modifiedFeedIds) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNMUTE_FEEDS;
        ra.activeFeedIds = activeFeedIds;
        ra.modifiedFeedIds = modifiedFeedIds;
        return ra;
    }

    public static ReadingAction setNotify(String feedId, List<String> notifyTypes, String notifyFilter) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.SET_NOTIFY;
        ra.feedId = feedId;
        if (notifyTypes == null) {
            ra.notifyTypes = new ArrayList<String>();
        } else {
            ra.notifyTypes = notifyTypes;
        }
        ra.notifyFilter = notifyFilter;
        return ra;
    }

	public ContentValues toContentValues() {
		ContentValues values = new ContentValues();
        values.put(DatabaseConstants.ACTION_TIME, time);
        values.put(DatabaseConstants.ACTION_TRIED, tried);
        values.put(DatabaseConstants.ACTION_TYPE, type.toString());
        switch (type) {

            case MARK_READ:
                if (storyHash != null) {
                    values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                } else if (feedSet != null) {
                    values.put(DatabaseConstants.ACTION_FEED_ID, feedSet.toCompactSerial());
                    if (olderThan != null) values.put(DatabaseConstants.ACTION_INCLUDE_OLDER, olderThan);
                    if (newerThan != null) values.put(DatabaseConstants.ACTION_INCLUDE_NEWER, newerThan);
                }
                break;
                
            case MARK_UNREAD:
                if (storyHash != null) {
                    values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                }
                break;

            case SAVE:
                values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                break;

            case UNSAVE:
                values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                break;

            case SHARE:
                values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_SOURCE_USER_ID, sourceUserId);
                values.put(DatabaseConstants.ACTION_COMMENT_TEXT, commentReplyText);
                break;

            case UNSHARE:
                values.put(DatabaseConstants.ACTION_STORY_HASH, storyHash);
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                break;

            case LIKE_COMMENT:
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_COMMENT_ID, commentUserId);
                break;

            case UNLIKE_COMMENT:
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_COMMENT_ID, commentUserId);
                break;

            case REPLY:
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_COMMENT_ID, commentUserId);
                values.put(DatabaseConstants.ACTION_COMMENT_TEXT, commentReplyText);
                break;

            case EDIT_REPLY:
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_COMMENT_ID, commentUserId);
                values.put(DatabaseConstants.ACTION_COMMENT_TEXT, commentReplyText);
                values.put(DatabaseConstants.ACTION_REPLY_ID, replyId);
                break;

            case DELETE_REPLY:
                values.put(DatabaseConstants.ACTION_STORY_ID, storyId);
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_COMMENT_ID, commentUserId);
                values.put(DatabaseConstants.ACTION_REPLY_ID, replyId);
                break;

            case MUTE_FEEDS:
                values.put(DatabaseConstants.ACTION_FEED_ID, DatabaseConstants.JsonHelper.toJson(activeFeedIds));
                values.put(DatabaseConstants.ACTION_MODIFIED_FEED_IDS, DatabaseConstants.JsonHelper.toJson(modifiedFeedIds));
                break;

            case UNMUTE_FEEDS:
                values.put(DatabaseConstants.ACTION_FEED_ID, DatabaseConstants.JsonHelper.toJson(activeFeedIds));
                values.put(DatabaseConstants.ACTION_MODIFIED_FEED_IDS, DatabaseConstants.JsonHelper.toJson(modifiedFeedIds));
                break;

            case SET_NOTIFY:
                values.put(DatabaseConstants.ACTION_FEED_ID, feedId);
                values.put(DatabaseConstants.ACTION_NOTIFY_FILTER, notifyFilter);
                values.put(DatabaseConstants.ACTION_NOTIFY_TYPES, DatabaseConstants.JsonHelper.toJson(notifyTypes));
                break;

            default:
                throw new IllegalStateException("cannot serialise uknown type of action.");

        }

		return values;
	}

	public static ReadingAction fromCursor(Cursor c) {
        long time = c.getLong(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_TIME));
        int tried = c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_TRIED));
		ReadingAction ra = new ReadingAction(time, tried);
        ra.type = ActionType.valueOf(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_TYPE)));
        if (ra.type == ActionType.MARK_READ) {
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
        } else if (ra.type == ActionType.MARK_UNREAD) {
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
        } else if (ra.type == ActionType.SAVE) {
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
        } else if (ra.type == ActionType.UNSAVE) {
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
        } else if (ra.type == ActionType.SHARE) {
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.sourceUserId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_SOURCE_USER_ID));
            ra.commentReplyText = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_TEXT));
        } else if (ra.type == ActionType.UNSHARE) {
            ra.storyHash = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_HASH));
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
        } else if (ra.type == ActionType.LIKE_COMMENT) {
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.commentUserId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_ID));
        } else if (ra.type == ActionType.UNLIKE_COMMENT) {
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.commentUserId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_ID));
        } else if (ra.type == ActionType.REPLY) {
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.commentUserId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_ID));
            ra.commentReplyText = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_TEXT));
        } else if (ra.type == ActionType.EDIT_REPLY) {
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.commentUserId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_ID));
            ra.commentReplyText = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_TEXT));
            ra.replyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_REPLY_ID));
        } else if (ra.type == ActionType.DELETE_REPLY) {
            ra.storyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_STORY_ID));
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.commentUserId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_COMMENT_ID));
            ra.replyId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_REPLY_ID));
        } else if (ra.type == ActionType.MUTE_FEEDS) {
            ra.activeFeedIds = DatabaseConstants.JsonHelper.fromJson(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID)), Set.class);
            ra.modifiedFeedIds = DatabaseConstants.JsonHelper.fromJson(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_MODIFIED_FEED_IDS)), Set.class);
        } else if (ra.type == ActionType.UNMUTE_FEEDS) {
            ra.activeFeedIds = DatabaseConstants.JsonHelper.fromJson(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID)), Set.class);
            ra.modifiedFeedIds = DatabaseConstants.JsonHelper.fromJson(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_MODIFIED_FEED_IDS)), Set.class);
        } else if (ra.type == ActionType.SET_NOTIFY) {
            ra.feedId = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_FEED_ID));
            ra.notifyFilter = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_NOTIFY_FILTER));
            ra.notifyTypes = DatabaseConstants.JsonHelper.fromJson(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_NOTIFY_TYPES)), List.class);
        } else {
            throw new IllegalStateException("cannot deserialise uknown type of action.");
        }
		return ra;
	}

    /**
     * Execute this action remotely via the API.
     */
    public NewsBlurResponse doRemote(APIManager apiManager, BlurDatabaseHelper dbHelper) {
        NewsBlurResponse result = null;
        int impact = 0;
        switch (type) {

            case MARK_READ:
                if (storyHash != null) {
                    result = apiManager.markStoryAsRead(storyHash);
                } else if (feedSet != null) {
                    result = apiManager.markFeedsAsRead(feedSet, olderThan, newerThan);
                }
                break;
                
            case MARK_UNREAD:
                result = apiManager.markStoryHashUnread(storyHash);
                break;

            case SAVE:
                result = apiManager.markStoryAsStarred(storyHash);
                break;

            case UNSAVE:
                result = apiManager.markStoryAsUnstarred(storyHash);
                break;

            case SHARE:
                StoriesResponse response = apiManager.shareStory(storyId, feedId, commentReplyText, sourceUserId);
                if ((response != null) && (response.story != null)) {
                    dbHelper.insertStories(response, true);
                    impact |= NbActivity.UPDATE_SOCIAL;
                } else {
                    com.newsblur.util.Log.i(this.getClass().getName(), "share failed to refresh story");
                }
                result = response;
                break;

            case UNSHARE:
                StoriesResponse unshareResponse = apiManager.unshareStory(storyId, feedId);
                if ((unshareResponse != null) && (unshareResponse.story != null)) {
                    dbHelper.insertStories(unshareResponse, true);
                    impact |= NbActivity.UPDATE_SOCIAL;
                } else {
                    com.newsblur.util.Log.i(this.getClass().getName(), "unshare failed to refresh story");
                }
                result = unshareResponse;
                break;

            case LIKE_COMMENT:
                result = apiManager.favouriteComment(storyId, commentUserId, feedId);
                break;

            case UNLIKE_COMMENT:
                result = apiManager.unFavouriteComment(storyId, commentUserId, feedId);
                break;

            case REPLY:
                result = apiManager.replyToComment(storyId, feedId, commentUserId, commentReplyText);
                break;

            case EDIT_REPLY:
                result = apiManager.editReply(storyId, feedId, commentUserId, replyId, commentReplyText);
                break;

            case DELETE_REPLY:
                result = apiManager.deleteReply(storyId, feedId, commentUserId, replyId);
                break;

            case MUTE_FEEDS:
            case UNMUTE_FEEDS:
                result = apiManager.saveFeedChooser(activeFeedIds);
                break;

            case SET_NOTIFY:
                result = apiManager.updateFeedNotifications(feedId, notifyTypes, notifyFilter);
                break;

            default:
                throw new IllegalStateException("cannot execute uknown type of action.");

        }

        NbActivity.updateAllActivities(impact);
        return result;
    }

    public int doLocal(BlurDatabaseHelper dbHelper) {
        return doLocal(dbHelper, false);
    }

    /**
     * Excecute this action on the local DB. These *must* be idempotent.
     *
     * @param isFollowup flag that this is a double-check invocation and is noncritical
     *
     * @return the union of update impact flags that resulted from this action.
     */
    public int doLocal(BlurDatabaseHelper dbHelper, boolean isFollowup) {
        int impact = 0;
        switch (type) {

            case MARK_READ:
                if (storyHash != null) {
                    dbHelper.setStoryReadState(storyHash, true);
                } else if (feedSet != null) {
                    dbHelper.markStoriesRead(feedSet, olderThan, newerThan);
                    dbHelper.updateLocalFeedCounts(feedSet);
                }
                impact |= NbActivity.UPDATE_METADATA;
                impact |= NbActivity.UPDATE_STORY;
                break;
                
            case MARK_UNREAD:
                dbHelper.setStoryReadState(storyHash, false);
                impact |= NbActivity.UPDATE_METADATA;
                break;

            case SAVE:
                dbHelper.setStoryStarred(storyHash, true);
                impact |= NbActivity.UPDATE_METADATA;
                break;

            case UNSAVE:
                dbHelper.setStoryStarred(storyHash, false);
                impact |= NbActivity.UPDATE_METADATA;
                break;

            case SHARE:
                if (isFollowup) break; // shares are only placeholders
                dbHelper.setStoryShared(storyHash, true);
                dbHelper.insertCommentPlaceholder(storyId, feedId, commentReplyText);
                impact |= NbActivity.UPDATE_SOCIAL;
                impact |= NbActivity.UPDATE_STORY;
                break;

            case UNSHARE:
                dbHelper.setStoryShared(storyHash, false);
                dbHelper.clearSelfComments(storyId);
                impact |= NbActivity.UPDATE_SOCIAL;
                impact |= NbActivity.UPDATE_STORY;
                break;

            case LIKE_COMMENT:
                // TODO need to use real comment ID
                // dbHelper.setCommentLiked(storyId, commentUserId, feedId, true);
                impact |= NbActivity.UPDATE_SOCIAL;
                break;

            case UNLIKE_COMMENT:
                // TODO need to use real comment ID
                // dbHelper.setCommentLiked(storyId, commentUserId, feedId, false);
                impact |= NbActivity.UPDATE_SOCIAL;
                break;

            case REPLY:
                // not possible locally, since the server generates the reply ID
                break;

            case EDIT_REPLY:
                // TODO
                // dbHelper.editReply(storyId, feedId, commentUserId, replyId, commentReplyText);
                impact |= NbActivity.UPDATE_SOCIAL;
                break;

            case DELETE_REPLY:
                // TODO
                // dbHelper.editReply(storyId, feedId, commentUserId, replyId);
                impact |= NbActivity.UPDATE_SOCIAL;
                break;
                
            case MUTE_FEEDS:
            case UNMUTE_FEEDS:
                dbHelper.setFeedsActive(modifiedFeedIds, type == ActionType.UNMUTE_FEEDS);
                impact |= NbActivity.UPDATE_METADATA;
                break;

            case SET_NOTIFY:
                impact |= NbActivity.UPDATE_METADATA;
                break;

            default:
                // not all actions have these, which is fine
        }
        return impact;
    }

}
