package com.newsblur.service;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.newsblur.util.AppConstants;

/**
 * First receiver in the chain that starts with the device.  Simply schedules another broadcast
 * that will periodicaly start the sync service.
 */
public class BootReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d(this.getClass().getName(), "triggering sync service from device boot");
        scheduleSyncService(context);
    }

    public static void scheduleSyncService(Context context) {
        Log.d(BootReceiver.class.getName(), "scheduling sync service");

        // wake up to check if a sync is needed less often than necessary to compensate for execution time
        long interval = AppConstants.BG_SERVICE_CYCLE_MILLIS;

        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        Intent i = new Intent(context, ServiceScheduleReceiver.class);
        PendingIntent pi = PendingIntent.getBroadcast(context, 0, i, PendingIntent.FLAG_CANCEL_CURRENT);
        alarmManager.setInexactRepeating(AlarmManager.ELAPSED_REALTIME_WAKEUP, interval, interval, pi);
    }
        
}
