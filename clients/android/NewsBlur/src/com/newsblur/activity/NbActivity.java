package com.newsblur.activity;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;

import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

import java.util.ArrayList;

/**
 * The base class for all Activities in the NewsBlur app.  Handles enforcement of
 * login state and tracking of sync/update broadcasts.
 */
public class NbActivity extends Activity {

    public static final int UPDATE_DB_READY = (1<<0);
    public static final int UPDATE_METADATA = (1<<1);
    public static final int UPDATE_STORY    = (1<<2);
    public static final int UPDATE_SOCIAL   = (1<<3);
    public static final int UPDATE_STATUS   = (1<<5);
    public static final int UPDATE_TEXT     = (1<<6);
    public static final int UPDATE_REBUILD  = (1<<7);

	private final static String UNIQUE_LOGIN_KEY = "uniqueLoginKey";
	private String uniqueLoginKey;

    /**
     * Keep track of all activie activities so they can be notified when the sync service
     * has updated the DB. This is essentially an ultra-lightweight implementation of a
     * local, unfiltered broadcast manager.
     */
    private static ArrayList<NbActivity> AllActivities = new ArrayList<NbActivity>();
	
	@Override
	protected void onCreate(Bundle bundle) {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onCreate");

        PrefsUtils.applyThemePreference(this);

		super.onCreate(bundle);

        FeedUtils.offerInitContext(this);

		if (bundle != null) {
			uniqueLoginKey = bundle.getString(UNIQUE_LOGIN_KEY);
		} 
        if (uniqueLoginKey == null) {
			uniqueLoginKey = PrefsUtils.getUniqueLoginKey(this);
		}
		finishIfNotLoggedIn();
	}

	@Override
	protected void onResume() {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onResume");
		super.onResume();
		finishIfNotLoggedIn();

        synchronized (AllActivities) {
            AllActivities.add(this);
        }
	}

	@Override
	protected void onPause() {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onPause");
		super.onPause();

        synchronized (AllActivities) {
            AllActivities.remove(this);
        }
	}

	protected void finishIfNotLoggedIn() {
		String currentLoginKey = PrefsUtils.getUniqueLoginKey(this);
		if(currentLoginKey == null || !currentLoginKey.equals(uniqueLoginKey)) {
			Log.d( this.getClass().getName(), "This activity was for a different login. finishing it.");
			finish();
		}
	}
	
	@Override
	protected void onSaveInstanceState(Bundle savedInstanceState) {
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onSave");
		savedInstanceState.putString(UNIQUE_LOGIN_KEY, uniqueLoginKey);
		super.onSaveInstanceState(savedInstanceState);
	}

    /**
     * Pokes the sync service to perform any pending sync actions.
     */
    protected void triggerSync() {
        Intent i = new Intent(this, NBSyncService.class);
        startService(i);
	}

    /**
     * Called on each NB activity after the DB has been updated by the sync service.
     *
     * @param updateType one or more of the UPDATE_* flags in this class to indicate the
     *        type of update being broadcast.
     */
    protected void handleUpdate(int updateType) {
        Log.w(this.getClass().getName(), "activity doesn't implement handleUpdate");
    }

    private void _handleUpdate(final int updateType) {
        runOnUiThread(new Runnable() {
            public void run() {
                handleUpdate(updateType);
            }
        });
    }

    /**
     * Notify all activities in the app that the DB has been updated. Should only be called
     * by the sync service, which owns updating the DB.
     */
    public static void updateAllActivities(int updateType) {
        synchronized (AllActivities) {
            for (NbActivity activity : AllActivities) {
                activity._handleUpdate(updateType);
            }
        }
    }

    public static void toastError(final String message) {
        synchronized (AllActivities) {
            for (final NbActivity activity : AllActivities) {
                activity.runOnUiThread(new Runnable() {
                    public void run() {
                        UIUtils.safeToast(activity, message, Toast.LENGTH_SHORT);
                    }
                });
            }
        }
    }

    /**
     * Gets the number of active/foreground NB activities. Used by the sync service to
     * determine if the app is active so we can honour user requests not to run in
     * the background.
     */
    public static int getActiveActivityCount() {
        return AllActivities.size();
    }

}
