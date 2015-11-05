package com.newsblur.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class ServiceScheduleReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d(this.getClass().getName(), "starting sync service");
        Intent i = new Intent(context, NBSyncService.class);
        context.startService(i);
    }
        
}
