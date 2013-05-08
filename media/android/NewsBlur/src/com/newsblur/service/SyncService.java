package com.newsblur.service;

import java.util.ArrayList;

import android.app.IntentService;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.ResultReceiver;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.APIClient;
import com.newsblur.network.APIConstants;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.SocialFeedResponse;
import com.newsblur.network.domain.StoriesResponse;

/**
 * The SyncService is based on an app architecture that tries to place network calls
 * (especially larger calls or those called regularly) on independent services, making the 
 * activity / fragment a passive receiver of its updates. This, along with data fragments for  
 * handling UI updates, throttles network access and ensures the UI is passively updated
 * and decoupled from network calls. Examples of other apps using this architecture include 
 * the NBCSportsTalk and Google I/O 2011 apps.
 */
public class SyncService extends IntentService {

	public static final String EXTRA_STATUS_RECEIVER = "resultReceiverExtra";
	public static final String EXTRA_TASK_FEED_ID = "taskFeedId";
	public static final String EXTRA_TASK_FOLDER_NAME = "taskFoldername";
	public static final String EXTRA_TASK_STORY_ID = "taskStoryId";
	public static final String EXTRA_TASK_STORIES = "stories";
	public static final String EXTRA_TASK_SOCIALFEED_ID = "userId";
	public static final String EXTRA_TASK_SOCIALFEED_USERNAME = "username";
	public static final String EXTRA_TASK_MARK_SOCIAL_JSON = "socialJson";
	public static final String EXTRA_TASK_PAGE_NUMBER = "page";
	public static final String EXTRA_TASK_MULTIFEED_IDS = "multi_feedids";

	// TODO: replace these with enums
    public final static int STATUS_RUNNING = 0x02;
	public final static int STATUS_FINISHED = 0x03;
	public final static int STATUS_ERROR = 0x04;
	public static final int STATUS_NO_MORE_UPDATES = 0x05;
	public static final int STATUS_FINISHED_CLOSE = 0x06;
	public static final int NOT_RUNNING = 0x01;
    public static final int STATUS_PARTIAL_PROGRESS = 0x07;

	public static final int EXTRA_TASK_FOLDER_UPDATE_TWO_STEP = 30;
	public static final int EXTRA_TASK_FOLDER_UPDATE_WITH_COUNT = 41;
	public static final int EXTRA_TASK_FEED_UPDATE = 31;
	public static final int EXTRA_TASK_SOCIALFEED_UPDATE = 34;
	public static final int EXTRA_TASK_MARK_SOCIALSTORY_READ = 35;
	public static final int EXTRA_TASK_MULTIFEED_UPDATE = 36;
	public static final int EXTRA_TASK_MARK_MULTIPLE_STORIES_READ = 37;
	public static final int EXTRA_TASK_ALL_STORIES = 38;
	public static final int EXTRA_TASK_DELETE_FEED = 39;
	public static final int EXTRA_TASK_MULTISOCIALFEED_UPDATE = 40;

	public APIClient apiClient;
	private APIManager apiManager;
	private ContentResolver contentResolver;
	public static final String SYNCSERVICE_TASK = "syncservice_task";


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
			if (receiver != null) {
				receiver.send(STATUS_RUNNING, Bundle.EMPTY);
			}
            // TODO: is it ever valid for receiver to be null? if not, we could factor out all
            //       the checks below

            Log.d( this.getClass().getName(), "Sync Intent: " + intent.getIntExtra(SYNCSERVICE_TASK , -1) );

			switch (intent.getIntExtra(SYNCSERVICE_TASK , -1)) {

			case EXTRA_TASK_FOLDER_UPDATE_TWO_STEP:
				// do a quick fetch of folders/feeds
                apiManager.getFolderFeedMapping(false);
                // notify UI of progress
                if (receiver != null) {
                    receiver.send(STATUS_PARTIAL_PROGRESS, Bundle.EMPTY);
                }
                // update feed counts
                apiManager.refreshFeedCounts();
                // UI will be notified again by default
				break;

			case EXTRA_TASK_FOLDER_UPDATE_WITH_COUNT:
				apiManager.getFolderFeedMapping(true);
				break;	

			case EXTRA_TASK_MARK_MULTIPLE_STORIES_READ:
				final ValueMultimap stories = (ValueMultimap) intent.getSerializableExtra(EXTRA_TASK_STORIES);
				ContentValues values = new ContentValues();
				values.put(APIConstants.PARAMETER_FEEDS_STORIES, stories.getJsonString());
				apiManager.markMultipleStoriesAsRead(values);
				break;	

			case EXTRA_TASK_MARK_SOCIALSTORY_READ:
				final String markSocialJson = intent.getStringExtra(EXTRA_TASK_MARK_SOCIAL_JSON);
				if (!TextUtils.isEmpty(markSocialJson)) {
					apiManager.markSocialStoryAsRead(markSocialJson);
				} else {
					Log.e(this.getClass().getName(), "No feed/story to mark as read included in SyncRequest");
					receiver.send(STATUS_ERROR, Bundle.EMPTY);
				}
				break;

			case EXTRA_TASK_FEED_UPDATE:
				if (!TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_FEED_ID))) {
					StoriesResponse storiesForFeed = apiManager.getStoriesForFeed(intent.getStringExtra(EXTRA_TASK_FEED_ID), intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER));
					if (storiesForFeed != null && storiesForFeed.stories.length != 0) {
						receiver.send(STATUS_FINISHED, null);
					} else {
						receiver.send(STATUS_NO_MORE_UPDATES, Bundle.EMPTY);
					}
				} else {
					Log.e(this.getClass().getName(), "No feed to refresh included in SyncRequest");
					receiver.send(STATUS_ERROR, Bundle.EMPTY);
				}
				break;


			case EXTRA_TASK_MULTIFEED_UPDATE:
				if (intent.getStringArrayExtra(EXTRA_TASK_MULTIFEED_IDS) != null) {
					StoriesResponse storiesForFeeds = apiManager.getStoriesForFeeds(intent.getStringArrayExtra(EXTRA_TASK_MULTIFEED_IDS), intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER));
					if (storiesForFeeds != null && storiesForFeeds.stories.length != 0) {
						receiver.send(STATUS_FINISHED, Bundle.EMPTY);
					} else {
						receiver.send(STATUS_NO_MORE_UPDATES, Bundle.EMPTY);
					}
				} else {
					Log.e(this.getClass().getName(), "No feed ids to refresh included in SyncRequest");
					receiver.send(STATUS_ERROR, Bundle.EMPTY);
				}
				break;

			case EXTRA_TASK_MULTISOCIALFEED_UPDATE:
				if (intent.getStringArrayExtra(EXTRA_TASK_MULTIFEED_IDS) != null) {
					SocialFeedResponse sharedStoriesForFeeds = apiManager.getSharedStoriesForFeeds(intent.getStringArrayExtra(EXTRA_TASK_MULTIFEED_IDS), intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER));
					if (sharedStoriesForFeeds != null && sharedStoriesForFeeds.stories.length != 0) {
						receiver.send(STATUS_FINISHED, null);
					} else {
						receiver.send(STATUS_NO_MORE_UPDATES, Bundle.EMPTY);
					}
				} else {
					Log.e(this.getClass().getName(), "No socialfeed ids to refresh included in SyncRequest");
					receiver.send(STATUS_ERROR, Bundle.EMPTY);
				}
				break;

			case EXTRA_TASK_DELETE_FEED:
				if (intent.getLongExtra(EXTRA_TASK_FEED_ID, -1) != -1) {
					Long feedToBeDeleted = intent.getLongExtra(EXTRA_TASK_FEED_ID, -1);
					if (apiManager.deleteFeed(feedToBeDeleted, intent.getStringExtra(EXTRA_TASK_FOLDER_NAME))) {
						Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(Long.toString(feedToBeDeleted)).build();
						contentResolver.delete(feedUri, null, null);
						receiver.send(STATUS_FINISHED_CLOSE, Bundle.EMPTY);
						return;
					} else {
						Log.e(this.getClass().getName(), "Error deleting feed");
						Toast.makeText(this, getResources().getString(R.string.error_deleting_feed), Toast.LENGTH_LONG).show();
						receiver.send(STATUS_ERROR, Bundle.EMPTY);
					}
				} else {
					Log.e(this.getClass().getName(), "No feed id to delete include in SyncRequest");
					receiver.send(STATUS_ERROR, Bundle.EMPTY);
				}
				break;	

			case EXTRA_TASK_SOCIALFEED_UPDATE:
				if (!TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_SOCIALFEED_ID)) && !TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_SOCIALFEED_USERNAME))) {
					SocialFeedResponse storiesForSocialFeed = apiManager.getStoriesForSocialFeed(intent.getStringExtra(EXTRA_TASK_SOCIALFEED_ID), intent.getStringExtra(EXTRA_TASK_SOCIALFEED_USERNAME), intent.getStringExtra(EXTRA_TASK_PAGE_NUMBER));
					if (storiesForSocialFeed != null && storiesForSocialFeed.stories.length != 0) {
						receiver.send(STATUS_FINISHED, null);
					} else {
						receiver.send(STATUS_NO_MORE_UPDATES, Bundle.EMPTY);
					}
				} else {
					Log.e(this.getClass().getName(), "Missing parameters for socialfeed SyncRequest");
					receiver.send(STATUS_ERROR, Bundle.EMPTY);
				}
				break;

			default:
				Log.e(this.getClass().getName(), "SyncService called without relevant task assignment");
				break;
			}

            Log.d( this.getClass().getName(), "Sync Intent complete");

		} catch (Exception e) {
			e.printStackTrace();
			Log.e(this.getClass().getName(), "Couldn't synchronise with Newsblur servers: " + e.getMessage(), e.getCause());
			if (receiver != null) {
				final Bundle bundle = new Bundle();
				bundle.putString(Intent.EXTRA_TEXT, e.toString());
				receiver.send(STATUS_ERROR, bundle);
			}
		}

		if (receiver != null) {
			receiver.send(STATUS_FINISHED, Bundle.EMPTY);
		} else {
			Log.e(this.getClass().getName(), "No receiver attached to Sync?");
		}
	}

}
