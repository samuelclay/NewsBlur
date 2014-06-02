package com.newsblur.activity;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

import com.newsblur.util.AppConstants;
import com.newsblur.util.PrefsUtils;

import java.util.ArrayList;

public class NbActivity extends Activity {

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
		super.onCreate(bundle);

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
        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "onSuspend");
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
     * Called on each NB activity after the DB has been updated by the sync service. This method
     * should return as quickly as possible.
     */
    protected void handleUpdate() {;}

    private void _handleUpdate() {
        runOnUiThread(new Runnable() {
            public void run() {
                handleUpdate();
            }
        });
    }

    /**
     * Notify all activities in the app that the DB has been updated.
     */
    public static void updateAllActivities() {
        Log.d(NbActivity.class.getName(), "updating all activities . . .");
        synchronized (AllActivities) {
            for (NbActivity activity : AllActivities) {
                activity._handleUpdate();
            }
        }
        Log.d(NbActivity.class.getName(), " . . . done updating all activities");
    }

}
