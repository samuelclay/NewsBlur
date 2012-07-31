package com.newsblur.service;

import android.app.IntentService;
import android.content.Intent;
import android.os.Bundle;
import android.os.ResultReceiver;
import android.text.TextUtils;
import android.util.Log;

import com.newsblur.network.APIClient;
import com.newsblur.network.APIManager;

/**
 * The SyncService is based on an app architecture that tries to place network calls
 * (especially larger calls or those called regularly) on independent services, making the 
 * activity / fragment a passive receiver of its updates. This, along with data fragments for  
 * handling UI updates, prevent network bottlenecks and ensure the UI is passively updated
 * and decoupled from network calls. Examples of other apps using this architecture include 
 * the NBCSportsTalk and Google I/O 2011 apps.
 */
public class SyncService extends IntentService {

	private static final String TAG = "SyncService";
	public static final String EXTRA_STATUS_RECEIVER = "resultReceiverExtra";
	public static final String EXTRA_TASK_FEED_ID = "taskFeedId";
	public static final String EXTRA_TASK_STORY_ID = "taskStoryId";
	
	public final static int STATUS_RUNNING = 0x02;
	public final static int STATUS_FINISHED = 0x03;
	public final static int STATUS_ERROR = 0x04;
	public static final int NOT_RUNNING = 0x01;
	
	public static final int EXTRA_TASK_FOLDER_UPDATE = 30;
	public static final int EXTRA_TASK_FEED_UPDATE = 31;
	public static final int EXTRA_TASK_REFRESH_COUNTS = 32;
	public static final int EXTRA_TASK_MARK_STORY_READ = 33;
	
	public APIClient apiClient;
	private APIManager apiManager;
	public static final String SYNCSERVICE_TASK = "syncservice_task";
	
	public SyncService() {
		super(TAG);
	}

	@Override
	public void onCreate() {
		super.onCreate();
		apiManager = new APIManager(this);
	}

	@Override
	protected void onHandleIntent(Intent intent) {
		Log.d(TAG, "Received SyncService handleIntent call.");
		final ResultReceiver receiver = intent.getParcelableExtra(EXTRA_STATUS_RECEIVER);
		try {
			if (receiver != null) {
				receiver.send(STATUS_RUNNING, Bundle.EMPTY);
			}
			
			switch (intent.getIntExtra(SYNCSERVICE_TASK , -1)) {
			case EXTRA_TASK_FOLDER_UPDATE:
				apiManager.getFolderFeedMapping();
				break;
			case EXTRA_TASK_REFRESH_COUNTS:
				apiManager.getFolderFeedMapping();
				break;	
			case EXTRA_TASK_MARK_STORY_READ:
				if (!TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_FEED_ID)) && !TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_STORY_ID))) {
					apiManager.markStoryAsRead(intent.getStringExtra(EXTRA_TASK_FEED_ID), intent.getStringExtra(EXTRA_TASK_STORY_ID));
				} else {
					Log.e(TAG, "No feed/story to mark as read included in SyncRequest");
					receiver.send(STATUS_ERROR, Bundle.EMPTY);
				}
				break;	
			case EXTRA_TASK_FEED_UPDATE:
				if (!TextUtils.isEmpty(intent.getStringExtra(EXTRA_TASK_FEED_ID))) {
					apiManager.getStoriesForFeed(intent.getStringExtra(EXTRA_TASK_FEED_ID));
				} else {
					Log.e(TAG, "No feed to refresh included in SyncRequest");
					receiver.send(STATUS_ERROR, Bundle.EMPTY);
				}
				break;	
			default:
				Log.e(TAG, "SyncService called without relevant task assignment");
				break;
			}
		} catch (Exception e) {
			e.printStackTrace();
			Log.e(TAG, "Couldn't synchronise with Newsblur servers: " + e.getMessage(), e.getCause());
			if (receiver != null) {
				final Bundle bundle = new Bundle();
				bundle.putString(Intent.EXTRA_TEXT, e.toString());
				receiver.send(STATUS_ERROR, bundle);
			}
		}

		if (receiver != null) {
			receiver.send(STATUS_FINISHED, Bundle.EMPTY);
		} else {
			Log.e(TAG, "No receiver attached to Sync?");
		}
	}

}
