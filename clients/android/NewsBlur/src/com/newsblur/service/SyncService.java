package com.newsblur.service;

import java.util.List;

import android.app.IntentService;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.ResultReceiver;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.APIConstants;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.SocialFeedResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

/**
 * A background-sync intent that, by virtue of extending IntentService, has several notable
 * features:
 *  * invocations are FIFO and executed serially
 *  * the OS picks an appropriate thread for execution that won't block the UI, but recycles
 *  * supports callbacks where necessary
 */
public class SyncService extends IntentService {

    public static final String EXTRA_TASK_TYPE = "syncServiceTaskType";
	public static final String EXTRA_STATUS_RECEIVER = "resultReceiverExtra";
	public static final String EXTRA_TASK_FEED_ID = "taskFeedId";
	public static final String EXTRA_TASK_FOLDER_NAME = "taskFoldername";
	public static final String EXTRA_TASK_STORY_ID = "taskStoryId";
	public static final String EXTRA_TASK_STORIES = "stories";
	public static final String EXTRA_TASK_SOCIALFEED_ID = "userId";
	public static final String EXTRA_TASK_SOCIALFEED_USERNAME = "username";
	public static final String EXTRA_TASK_MARK_SOCIAL_JSON = "socialJson";
	public static final String EXTRA_TASK_PAGE_NUMBER = "page";
	public static final String EXTRA_TASK_ORDER = "order";
	public static final String EXTRA_TASK_READ_FILTER = "read_filter";
	public static final String EXTRA_TASK_MULTIFEED_IDS = "multi_feedids";

    public enum SyncStatus {
        STATUS_RUNNING,
        STATUS_FINISHED,
        STATUS_NO_MORE_UPDATES,
        NOT_RUNNING,
        STATUS_PARTIAL_PROGRESS,
    };

    public enum TaskType {
        FOLDER_UPDATE_TWO_STEP,
        FOLDER_UPDATE_WITH_COUNT,
        FEED_UPDATE,
        SOCIALFEED_UPDATE,
        MULTIFEED_UPDATE,
        MULTISOCIALFEED_UPDATE,
        STARRED_STORIES_UPDATE
    };

	private APIManager apiManager;
	private ContentResolver contentResolver;

	public SyncService() {
		super(SyncService.class.getName());
	}

	@Override
	public void onCreate() {
		super.onCreate();
		apiManager = new APIManager(this);
		contentResolver = getContentResolver();
	}

	@Override
	protected void onHandleIntent(Intent intent) {
		final ResultReceiver receiver = intent.getParcelableExtra(EXTRA_STATUS_RECEIVER);
		try {
            TaskType taskType = (TaskType) intent.getSerializableExtra(EXTRA_TASK_TYPE);
            Log.d( this.getClass().getName(), "Sync Intent: " + taskType );

			if (receiver != null) {
				receiver.send(SyncStatus.STATUS_RUNNING.ordinal(), Bundle.EMPTY);
			}

            // an extra result code to callback before the final STATUS_FINISHED that is always sent
            SyncStatus resultStatus = null;

			switch (taskType) {

			case FOLDER_UPDATE_TWO_STEP:
				// do a quick fetch of folders/feeds
                apiManager.getFolderFeedMapping(false);
                // notify UI of progress
                if (receiver != null) {
                    receiver.send(SyncStatus.STATUS_PARTIAL_PROGRESS.ordinal(), Bundle.EMPTY);
                }
                // update feed counts
                apiManager.refreshFeedCounts();
                // UI will be notified again by default
				break;

			case FOLDER_UPDATE_WITH_COUNT:
				apiManager.getFolderFeedMapping(true);
				break;	

			case FEED_UPDATE:
				if (!TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_FEED_ID))) {
					StoriesResponse storiesForFeed = apiManager.getStoriesForFeed(intent.getStringExtra(EXTRA_TASK_FEED_ID), intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER), (StoryOrder) intent.getSerializableExtra(EXTRA_TASK_ORDER), (ReadFilter) intent.getSerializableExtra(EXTRA_TASK_READ_FILTER));
					if (storiesForFeed == null || storiesForFeed.stories.length == 0) {
						resultStatus = SyncStatus.STATUS_NO_MORE_UPDATES;
					}
				} else {
					Log.e(this.getClass().getName(), "No feed to refresh included in SyncRequest");
				}
				break;

			case MULTIFEED_UPDATE:
				if (intent.getStringArrayExtra(EXTRA_TASK_MULTIFEED_IDS) != null) {
					StoriesResponse storiesForFeeds = apiManager.getStoriesForFeeds(intent.getStringArrayExtra(EXTRA_TASK_MULTIFEED_IDS), intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER), (StoryOrder) intent.getSerializableExtra(EXTRA_TASK_ORDER), (ReadFilter) intent.getSerializableExtra(EXTRA_TASK_READ_FILTER));
					if (storiesForFeeds == null || storiesForFeeds.stories.length == 0) {
						resultStatus = SyncStatus.STATUS_NO_MORE_UPDATES;
					}
				} else {
					Log.e(this.getClass().getName(), "No feed ids to refresh included in SyncRequest");
				}
				break;

			case MULTISOCIALFEED_UPDATE:
				if (intent.getStringArrayExtra(EXTRA_TASK_MULTIFEED_IDS) != null) {
					SocialFeedResponse sharedStoriesForFeeds = apiManager.getSharedStoriesForFeeds(intent.getStringArrayExtra(EXTRA_TASK_MULTIFEED_IDS), intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER), (StoryOrder) intent.getSerializableExtra(EXTRA_TASK_ORDER), (ReadFilter) intent.getSerializableExtra(EXTRA_TASK_READ_FILTER));
					if (sharedStoriesForFeeds == null || sharedStoriesForFeeds.stories.length == 0) {
						resultStatus = SyncStatus.STATUS_NO_MORE_UPDATES;
					}
				} else {
					Log.e(this.getClass().getName(), "No socialfeed ids to refresh included in SyncRequest");
				}
				break;

			case STARRED_STORIES_UPDATE:
                StoriesResponse starredStories = apiManager.getStarredStories(intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER));
                if (starredStories == null || starredStories.stories.length == 0) {
                    resultStatus = SyncStatus.STATUS_NO_MORE_UPDATES;
                }
				break;

			case SOCIALFEED_UPDATE:
				if (!TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_SOCIALFEED_ID)) && !TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_SOCIALFEED_USERNAME))) {
					SocialFeedResponse storiesForSocialFeed = apiManager.getStoriesForSocialFeed(intent.getStringExtra(EXTRA_TASK_SOCIALFEED_ID), intent.getStringExtra(EXTRA_TASK_SOCIALFEED_USERNAME), intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER), (StoryOrder) intent.getSerializableExtra(EXTRA_TASK_ORDER), (ReadFilter) intent.getSerializableExtra(EXTRA_TASK_READ_FILTER));
					if (storiesForSocialFeed == null || storiesForSocialFeed.stories.length == 0) {
						resultStatus = SyncStatus.STATUS_NO_MORE_UPDATES;
					}
				} else {
					Log.e(this.getClass().getName(), "Missing parameters for socialfeed SyncRequest");
				}
				break;

			default:
				Log.e(this.getClass().getName(), "SyncService called without relevant task assignment");
				break;
			}

            // send the first result code if it was set.  The STATUS_FINISHED is sent below
            if ((receiver != null) && (resultStatus != null)) {
               receiver.send(resultStatus.ordinal(), Bundle.EMPTY);
            }

            Log.d( this.getClass().getName(), "Sync Intent complete");

		} catch (Exception e) {
			Log.e(this.getClass().getName(), "Couldn't synchronise with NewsBlur servers: " + e.getMessage(), e.getCause());
			e.printStackTrace();
		} finally {
             if (receiver != null) {
                receiver.send(SyncStatus.STATUS_FINISHED.ordinal(), Bundle.EMPTY);
             }
        }

	}

}
