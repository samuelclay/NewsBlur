package com.newsblur.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import androidx.annotation.Nullable;

import com.newsblur.widget.WidgetUtils;

public class TimeChangeReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, @Nullable Intent intent) {
        if (intent != null && intent.getAction() != null
                && intent.getAction().equals(Intent.ACTION_TIME_CHANGED)) {
            com.newsblur.util.Log.d(TimeChangeReceiver.class.getName(), "Received " + Intent.ACTION_TIME_CHANGED + " - reset widget sync");
            WidgetUtils.resetWidgetUpdate(context);
        }
    }
}
