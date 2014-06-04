package com.newsblur.service;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.os.PowerManager;
import android.util.Log;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.network.APIManager;
import com.newsblur.util.PrefsUtils;

/**
 * A background service to handle synchronisation with the NB servers.
 *
 * It is the design goal of this service to handle all communication with the API.
 * Activities and fragments should enqueue actions in the DB or use the methods
 * provided herein to request an action and let the service handle things.
 *
 * Per the contract of the Service class, at most one instance shall be created. It
 * will be preserved and re-used where possible.  Additionally, regularly scheduled
 * invocations are requested via the Main activity and BootReceiver.
 */
public class NBSyncService extends Service {

    private volatile static boolean SyncRunning = false;
    private volatile static boolean DoFeedsFolders = false;

	private APIManager apiManager;

	@Override
	public void onCreate() {
		super.onCreate();
        Log.d(this.getClass().getName(), "onCreate");
		apiManager = new APIManager(this);
        PrefsUtils.checkForUpgrade(this);
	}

    /**
     * Called serially, once per "start" of the service.  This serves as a wakeup call
     * that the service should check for outstanding work.
     */
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (PrefsUtils.isOfflineEnabled(this) || (NbActivity.getActiveActivityCount() > 0)) {
            // Services actually get invoked on the main system thread, and are not
            // allowed to do tangible work.  We spawn a thread to do so.
            new Thread(new Runnable() {
                public void run() {
                    doSync();
                }
            }).start();
        } else {
            Log.d(this.getClass().getName(), "Skipping sync: app not active and background sync not enabled.");
        } 

        // indicate to the system that the service should be alive when started, but
        // needn't necessarily persist under memory pressure
        return Service.START_NOT_STICKY;
    }

    /**
     * Do the actual work of syncing.
     */
    private synchronized void doSync() {
        Log.d(this.getClass().getName(), "starting sync . . .");

        PowerManager pm = (PowerManager) getApplicationContext().getSystemService(POWER_SERVICE);
        PowerManager.WakeLock wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this.getClass().getSimpleName());
        try {
            wl.acquire();

            SyncRunning = true;
            NbActivity.updateAllActivities();


            if (DoFeedsFolders || PrefsUtils.isTimeToAutoSync(this)) {
                apiManager.getFolderFeedMapping(true);
                PrefsUtils.updateLastSyncTime(this);
                DoFeedsFolders = false;
            }

            SyncRunning = false;
            NbActivity.updateAllActivities();

        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Sync error.", e);
        } finally {
            wl.release();
            Log.d(this.getClass().getName(), " . . . sync done");
        }
    }

    public static boolean isSyncRunning() {
        return SyncRunning;
    }

    /**
     * Force a refresh of feed/folder data on the next sync, even if enough time
     * hasn't passed for an autosync.
     */
    public static void forceFeedsFolders() {
        DoFeedsFolders = true;
    }

    @Override
    public void onDestroy() {
        Log.d(this.getClass().getName(), "onDestroy");
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

}
