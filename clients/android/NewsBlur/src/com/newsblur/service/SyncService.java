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

    public enum SyncStatus {
        STATUS_RUNNING,
        STATUS_FINISHED,
        STATUS_NO_MORE_UPDATES,
        NOT_RUNNING,
        STATUS_PARTIAL_PROGRESS,
    };

    public enum TaskType {
        FOLDER_UPDATE_TWO_STEP,
        FOLDER_UPDATE_WITH_COUNT
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
