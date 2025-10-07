package com.newsblur.util;

import static com.newsblur.service.NbSyncManager.UPDATE_INTEL;
import static com.newsblur.service.NbSyncManager.UPDATE_METADATA;
import static com.newsblur.service.NbSyncManager.UPDATE_SOCIAL;
import static com.newsblur.service.NbSyncManager.UPDATE_STORY;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.Serializable;

import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.Classifier;
import com.newsblur.network.domain.CommentResponse;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.APIManager;
import com.newsblur.service.NbSyncManager;
import com.newsblur.service.NBSyncService;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

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
        SET_NOTIFY,
        INSTA_FETCH,
        UPDATE_INTEL,
        RENAME_FEED
    };

    private long time;
    private int tried;
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
    private List<String> userTags;
    private Classifier classifier;
    private String newFeedName;

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

    public static ReadingAction markStoryRead(@Nullable String hash) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.MARK_READ;
        ra.storyHash = hash;
        return ra;
    }

    public static ReadingAction markStoryUnread(@Nullable String hash) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.MARK_UNREAD;
        ra.storyHash = hash;
        return ra;
    }

    public static ReadingAction saveStory(@Nullable String hash, @Nullable List<String> userTags) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.SAVE;
        ra.storyHash = hash;
        if (userTags == null) {
            ra.userTags = new ArrayList<>();
        } else {
            ra.userTags = userTags;
        }
        return ra;
    }

    public static ReadingAction unsaveStory(@Nullable String hash) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNSAVE;
        ra.storyHash = hash;
        return ra;
    }

    public static ReadingAction markFeedRead(@NonNull FeedSet fs, @Nullable Long olderThan, @Nullable Long newerThan) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.MARK_READ;
        ra.feedSet = fs;
        ra.olderThan = olderThan;
        ra.newerThan = newerThan;
        return ra;
    }

    public static ReadingAction shareStory(@Nullable String hash, @Nullable String storyId, @Nullable String feedId, @Nullable String sourceUserId, @Nullable String commentReplyText) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.SHARE;
        ra.storyHash = hash;
        ra.storyId = storyId;
        ra.feedId = feedId;
        ra.sourceUserId = sourceUserId;
        ra.commentReplyText = commentReplyText;
        return ra;
    }

    public static ReadingAction unshareStory(@Nullable String hash, @Nullable String storyId, @Nullable String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNSHARE;
        ra.storyHash = hash;
        ra.storyId = storyId;
        ra.feedId = feedId;
        return ra;
    }

    public static ReadingAction likeComment(@Nullable String storyId, @Nullable String commentUserId, @Nullable String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.LIKE_COMMENT;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        return ra;
    }

    public static ReadingAction unlikeComment(@Nullable String storyId, @Nullable String commentUserId, @Nullable String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNLIKE_COMMENT;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        return ra;
    }

    public static ReadingAction replyToComment(@Nullable String storyId, @Nullable String feedId, @Nullable String commentUserId, @Nullable String commentReplyText) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.REPLY;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        ra.commentReplyText = commentReplyText;
        return ra;
    }

    public static ReadingAction updateReply(@Nullable String storyId, @Nullable String feedId, @Nullable String commentUserId, @Nullable String replyId, @Nullable String commentReplyText) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.EDIT_REPLY;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        ra.commentReplyText = commentReplyText;
        ra.replyId = replyId;
        return ra;
    }

    public static ReadingAction deleteReply(@Nullable String storyId, @Nullable String feedId, @Nullable String commentUserId, @Nullable String replyId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.DELETE_REPLY;
        ra.storyId = storyId;
        ra.commentUserId = commentUserId;
        ra.feedId = feedId;
        ra.replyId = replyId;
        return ra;
    }

    public static ReadingAction muteFeeds(@NonNull Set<String> activeFeedIds, @NonNull Set<String> modifiedFeedIds) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.MUTE_FEEDS;
        ra.activeFeedIds = activeFeedIds;
        ra.modifiedFeedIds = modifiedFeedIds;
        return ra;
    }

    public static ReadingAction unmuteFeeds(@NonNull Set<String> activeFeedIds, @NonNull Set<String> modifiedFeedIds) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UNMUTE_FEEDS;
        ra.activeFeedIds = activeFeedIds;
        ra.modifiedFeedIds = modifiedFeedIds;
        return ra;
    }

    public static ReadingAction setNotify(@Nullable String feedId, @Nullable List<String> notifyTypes, @Nullable String notifyFilter) {
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

    public static ReadingAction instaFetch(@Nullable String feedId) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.INSTA_FETCH;
        ra.feedId = feedId;
        return ra;
    }

    public static ReadingAction updateIntel(@Nullable String feedId, @Nullable Classifier classifier, @Nullable FeedSet fs) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.UPDATE_INTEL;
        ra.feedId = feedId;
        ra.classifier = classifier;
        ra.feedSet = fs;
        return ra;
    }

    public static ReadingAction renameFeed(@Nullable String feedId, @Nullable String newFeedName) {
        ReadingAction ra = new ReadingAction();
        ra.type = ActionType.RENAME_FEED;
        ra.feedId = feedId;
        ra.newFeedName = newFeedName;
        return ra;
    }

	public ContentValues toContentValues() {
		ContentValues values = new ContentValues();
        values.put(DatabaseConstants.ACTION_TIME, time);
        values.put(DatabaseConstants.ACTION_TRIED, tried);
        // because ReadingActions will have to represent a wide and ever-growing variety of interactions,
        // the number of parameters will continue growing unbounded.  to avoid having to frequently modify the
        // database and support a table with dozens or hundreds of columns that are only ever used at a low
        // cardinality, only the ACTION_TIME and ACTION_TRIED values are stored in columns of their own, and
        // all remaining fields are frozen as JSON, since they are never queried upon.
        values.put(DatabaseConstants.ACTION_PARAMS, DatabaseConstants.JsonHelper.toJson(this));
		return values;
	}

	public static ReadingAction fromCursor(@NonNull Cursor c) {
        long time = c.getLong(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_TIME));
        int tried = c.getInt(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_TRIED));
        String params = c.getString(c.getColumnIndexOrThrow(DatabaseConstants.ACTION_PARAMS));
		ReadingAction ra = DatabaseConstants.JsonHelper.fromJson(params, ReadingAction.class);
        ra.time = time;
        ra.tried = tried;
		return ra;
	}

    /**
     * Execute this action remotely via the API.
     */
    public NewsBlurResponse doRemote(@NonNull APIManager apiManager, @NonNull BlurDatabaseHelper dbHelper, @NonNull StateFilter stateFilter) {
        // generic response to return
        NewsBlurResponse result = null;
        // optional specific responses that are locally actionable
        StoriesResponse storiesResponse = null;
        CommentResponse commentResponse = null;
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
                result = apiManager.markStoryAsStarred(storyHash, userTags);
                break;

            case UNSAVE:
                result = apiManager.markStoryAsUnstarred(storyHash);
                break;

            case SHARE:
                storiesResponse = apiManager.shareStory(storyId, feedId, commentReplyText, sourceUserId);
                break;

            case UNSHARE:
                storiesResponse = apiManager.unshareStory(storyId, feedId);
                break;

            case LIKE_COMMENT:
                result = apiManager.favouriteComment(storyId, commentUserId, feedId);
                break;

            case UNLIKE_COMMENT:
                result = apiManager.unFavouriteComment(storyId, commentUserId, feedId);
                break;

            case REPLY:
                commentResponse = apiManager.replyToComment(storyId, feedId, commentUserId, commentReplyText);
                break;

            case EDIT_REPLY:
                 commentResponse = apiManager.editReply(storyId, feedId, commentUserId, replyId, commentReplyText);
                break;

            case DELETE_REPLY:
                commentResponse = apiManager.deleteReply(storyId, feedId, commentUserId, replyId);
                break;

            case MUTE_FEEDS:
            case UNMUTE_FEEDS:
                result = apiManager.saveFeedChooser(activeFeedIds);
                break;

            case SET_NOTIFY:
                result = apiManager.updateFeedNotifications(feedId, notifyTypes, notifyFilter);
                break;

            case INSTA_FETCH:
                result = apiManager.instaFetch(feedId);
                // also trigger a recount, which will unflag the feed as pending
                NBSyncService.addRecountCandidates(FeedSet.singleFeed(feedId));
                NBSyncService.flushRecounts();
                break;

            case UPDATE_INTEL:
                result = apiManager.updateFeedIntel(feedId, classifier);
                // also reset stories for the calling view so they get new scores
                NBSyncService.resetFetchState(feedSet);
                // and recount unreads to get new focus counts
                NBSyncService.addRecountCandidates(feedSet);
                break;

            case RENAME_FEED:
                result = apiManager.renameFeed(feedId, newFeedName);
                break;

            default:
                throw new IllegalStateException("cannot execute uknown type of action.");

        }
        
        if (storiesResponse != null) {
            result = storiesResponse;
            if (storiesResponse.story != null) {
                dbHelper.updateStory(storiesResponse, stateFilter, true);
            } else {
                com.newsblur.util.Log.w(this, "failed to refresh story data after action");
            }
            impact |= NbSyncManager.UPDATE_SOCIAL;
        }
        if (commentResponse != null) {
            result = commentResponse;
            if (commentResponse.comment != null) {
                dbHelper.updateComment(commentResponse, storyId);
            } else {
                com.newsblur.util.Log.w(this, "failed to refresh comment data after action");
            }
            impact |= NbSyncManager.UPDATE_SOCIAL;
        }
        if (result != null && impact != 0) {
            result.impactCode = impact;
        }
        return result;
    }

    public int doLocal(@NonNull Context context, @NonNull BlurDatabaseHelper dbHelper) {
        return doLocal(context, dbHelper, false);
    }

    /**
     * Excecute this action on the local DB. These *must* be idempotent.
     *
     * @param isFollowup flag that this is a double-check invocation and is noncritical
     *
     * @return the union of update impact flags that resulted from this action.
     */
    public int doLocal(@NonNull Context context, @NonNull BlurDatabaseHelper dbHelper, boolean isFollowup) {
        String userId = PrefsUtils.getUserId(context);
        int impact = 0;
        switch (type) {

            case MARK_READ:
                if (storyHash != null) {
                    dbHelper.setStoryReadState(storyHash, true);
                } else if (feedSet != null) {
                    dbHelper.markStoriesRead(feedSet, olderThan, newerThan);
                    dbHelper.updateLocalFeedCounts(feedSet);
                }
                impact |= UPDATE_METADATA;
                impact |= UPDATE_STORY;
                break;
                
            case MARK_UNREAD:
                dbHelper.setStoryReadState(storyHash, false);
                impact |= UPDATE_METADATA;
                break;

            case SAVE:
                dbHelper.setStoryStarred(storyHash, userTags, true);
                impact |= UPDATE_METADATA;
                break;

            case UNSAVE:
                dbHelper.setStoryStarred(storyHash, null, false);
                impact |= UPDATE_METADATA;
                break;

            case SHARE:
                if (isFollowup) break; // shares are only placeholders
                dbHelper.setStoryShared(storyHash, userId, true);
                dbHelper.insertCommentPlaceholder(storyId, userId, commentReplyText);
                impact |= UPDATE_SOCIAL;
                impact |= UPDATE_STORY;
                break;

            case UNSHARE:
                dbHelper.setStoryShared(storyHash, userId, false);
                dbHelper.clearSelfComments(storyId, userId);
                impact |= UPDATE_SOCIAL;
                impact |= UPDATE_STORY;
                break;

            case LIKE_COMMENT:
                dbHelper.setCommentLiked(storyId, commentUserId, userId, true);
                impact |= UPDATE_SOCIAL;
                break;

            case UNLIKE_COMMENT:
                dbHelper.setCommentLiked(storyId, commentUserId, userId, false);
                impact |= UPDATE_SOCIAL;
                break;

            case REPLY:
                if (isFollowup) break; // replies are only placeholders
                dbHelper.insertReplyPlaceholder(storyId, userId, commentUserId, commentReplyText);
                break;

            case EDIT_REPLY:
                dbHelper.editReply(replyId, commentReplyText);
                impact |= UPDATE_SOCIAL;
                break;

            case DELETE_REPLY:
                dbHelper.deleteReply(replyId);
                impact |= UPDATE_SOCIAL;
                break;
                
            case MUTE_FEEDS:
            case UNMUTE_FEEDS:
                dbHelper.setFeedsActive(modifiedFeedIds, type == ActionType.UNMUTE_FEEDS);
                impact |= UPDATE_METADATA;
                break;

            case SET_NOTIFY:
                impact |= UPDATE_METADATA;
                break;

            case INSTA_FETCH:
                if (isFollowup) break; // non-idempotent and purely graphical
                dbHelper.setFeedFetchPending(feedId);
                break;

            case UPDATE_INTEL:
                // TODO: because intel is always calculated on the server, we can change the disposition of
                // individual tags and authors etc in the UI, but story scores won't be updated until a refresh.
                // for best offline operation, we could try to duplicate that business logic locally
                dbHelper.clearClassifiersForFeed(feedId);
                classifier.feedId = feedId; 
                dbHelper.insertClassifier(classifier);
                impact |= UPDATE_INTEL;
                break;

            case RENAME_FEED:
                dbHelper.renameFeed(feedId, newFeedName);
                impact |= UPDATE_METADATA;
                break;

            default:
                // not all actions have these, which is fine
        }
        return impact;
    }

}
