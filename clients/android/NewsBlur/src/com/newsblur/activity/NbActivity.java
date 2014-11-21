package com.newsblur.activity;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.PrefsUtils;

import java.util.ArrayList;

/**
 * The base class for all Activities in the NewsBlur app.  Handles enforcement of
 * login state and tracking of sync/update broadcasts.
 */
public class NbActivity extends Activity {

	private final static String UNIQUE_LOGIN_KEY = "uniqueLoginKey";
	private String uniqueLoginKey;

    protected BlurDatabaseHelper dbHelper;

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

		if (bundle != null) {
			uniqueLoginKey = bundle.getString(UNIQUE_LOGIN_KEY);
		} 
        if (uniqueLoginKey == null) {
			uniqueLoginKey = PrefsUtils.getUniqueLoginKey(this);
		}
		finishIfNotLoggedIn();

        dbHelper = new BlurDatabaseHelper(this);
	}

    @Override
    public void onDestroy() {
        try {
            dbHelper.close();
        } catch (Exception e) {
            ; // Activity is already dead
        }

        super.onDestroy();
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
     * Called on each NB activity after the DB has been updated by the sync service. This method
     * should return as quickly as possible.
     */
    protected void handleUpdate() {
        Log.w(this.getClass().getName(), "activity doesn't implement handleUpdate");
    }

    private void _handleUpdate() {
        runOnUiThread(new Runnable() {
            public void run() {
                handleUpdate();
            }
        });
    }

    /**
     * Notify all activities in the app that the DB has been updated. Should only be called
     * by the sync service, which owns updating the DB.
     */
    public static void updateAllActivities() {
        synchronized (AllActivities) {
            for (NbActivity activity : AllActivities) {
                activity._handleUpdate();
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
