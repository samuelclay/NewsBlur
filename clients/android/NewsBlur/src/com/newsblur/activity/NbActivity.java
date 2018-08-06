package com.newsblur.activity;

import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.widget.Toast;

import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.PrefConstants.ThemeValue;
import com.newsblur.util.UIUtils;

import java.util.ArrayList;

/**
 * The base class for all Activities in the NewsBlur app.  Handles enforcement of
 * login state and tracking of sync/update broadcasts.
 */
public class NbActivity extends FragmentActivity {

    public static final int UPDATE_DB_READY = (1<<0);
    public static final int UPDATE_METADATA = (1<<1);
    public static final int UPDATE_STORY    = (1<<2);
    public static final int UPDATE_SOCIAL   = (1<<3);
    public static final int UPDATE_INTEL    = (1<<4);
    public static final int UPDATE_STATUS   = (1<<5);
    public static final int UPDATE_TEXT     = (1<<6);
    public static final int UPDATE_REBUILD  = (1<<7);

	private final static String UNIQUE_LOGIN_KEY = "uniqueLoginKey";
	private String uniqueLoginKey;

    private ThemeValue lastTheme = null;

    /**
     * Keep track of all activie activities so they can be notified when the sync service
     * has updated the DB. This is essentially an ultra-lightweight implementation of a
     * local, unfiltered broadcast manager.
     */
    private static ArrayList<NbActivity> AllActivities = new ArrayList<NbActivity>();
	
	@Override
	protected void onCreate(Bundle bundle) {
        com.newsblur.util.Log.offerContext(this);
        com.newsblur.util.Log.d(this, "onCreate");

        // this is not redundant to the applyThemePreference() call in onResume. the theme needs to be set
        // before onCreate() in order to work
        PrefsUtils.applyThemePreference(this);
        lastTheme = PrefsUtils.getSelectedTheme(this);

        // in rare cases of process interruption or DB corruption, an activity can launch without valid
        // login creds.  redirect the user back to the loging workflow.
        if (PrefsUtils.getUserId(this) == null) {
            com.newsblur.util.Log.e(this, "post-login activity launched without valid login.");
            PrefsUtils.logout(this);
            finish();
        }

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
        com.newsblur.util.Log.d(this, "onResume" + UIUtils.getMemoryUsageDebug(this));
		super.onResume();
		finishIfNotLoggedIn();

        // is is possible that another activity changed the theme while we were on the backstack
        if (lastTheme != PrefsUtils.getSelectedTheme(this)) {
            lastTheme = PrefsUtils.getSelectedTheme(this);
            PrefsUtils.applyThemePreference(this);
            UIUtils.restartActivity(this);
        }

        synchronized (AllActivities) {
            AllActivities.add(this);
        }
	}

	@Override
	protected void onPause() {
        com.newsblur.util.Log.d(this.getClass().getName(), "onPause");
		super.onPause();

        synchronized (AllActivities) {
            AllActivities.remove(this);
        }
	}

	protected void finishIfNotLoggedIn() {
		String currentLoginKey = PrefsUtils.getUniqueLoginKey(this);
		if(currentLoginKey == null || !currentLoginKey.equals(uniqueLoginKey)) {
			com.newsblur.util.Log.d(this.getClass().getName(), "This activity was for a different login. finishing it.");
			finish();
		}
	}
	
	@Override
	protected void onSaveInstanceState(Bundle savedInstanceState) {
        com.newsblur.util.Log.d(this, "onSave");
		savedInstanceState.putString(UNIQUE_LOGIN_KEY, uniqueLoginKey);
		super.onSaveInstanceState(savedInstanceState);
	}

    /**
     * Pokes the sync service to perform any pending sync actions.
     */
    protected void triggerSync() {
        FeedUtils.triggerSync(this);
	}

    /**
     * Called on each NB activity after the DB has been updated by the sync service.
     *
     * @param updateType one or more of the UPDATE_* flags in this class to indicate the
     *        type of update being broadcast.
     */
    protected void handleUpdate(int updateType) {
        com.newsblur.util.Log.w(this, "activity doesn't implement handleUpdate");
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
