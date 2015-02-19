package com.newsblur.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class NetStateReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        // poke the sync service when network state changes, in case we were offline
        if (!NBSyncService.OfflineNow) return;
        Intent i = new Intent(context, NBSyncService.class);
        context.startService(i);
    }

}
