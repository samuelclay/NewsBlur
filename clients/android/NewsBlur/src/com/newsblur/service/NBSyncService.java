package com.newsblur.service;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;
import android.os.PowerManager;
import android.util.Log;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.network.APIManager;

public class NBSyncService extends Service {

    private static boolean SyncRunning = false;

	private APIManager apiManager;

	@Override
	public void onCreate() {
		super.onCreate();
        Log.d(this.getClass().getName(), "onCreate");
		apiManager = new APIManager(this);
	}

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(this.getClass().getName(), "onStartCommand");

        // TODO: check for sync flag or realtime flag

        new Thread(new Runnable() {
            public void run() {
                doSync();
            }
        }).start();

        Log.d(this.getClass().getName(), "onStartCommand complete");

        return Service.START_NOT_STICKY;
    }

    private synchronized void doSync() {
        Log.d(this.getClass().getName(), "starting sync . . .");

        PowerManager pm = (PowerManager) getApplicationContext().getSystemService(POWER_SERVICE);
        PowerManager.WakeLock wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this.getClass().getSimpleName());
        try {
            wl.acquire();

            SyncRunning = true;
            NbActivity.updateAllActivities();

            apiManager.getFolderFeedMapping(true);

            SyncRunning = false;
            NbActivity.updateAllActivities();

        } finally {
            wl.release();
            Log.d(this.getClass().getName(), " . . . sync done");
        }
    }

    public static boolean isSyncRunning() {
        return SyncRunning;
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
