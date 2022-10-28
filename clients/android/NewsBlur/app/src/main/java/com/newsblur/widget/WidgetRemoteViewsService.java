package com.newsblur.widget;

import android.content.Intent;
import android.widget.RemoteViewsService;

import com.newsblur.util.Log;

public class WidgetRemoteViewsService extends RemoteViewsService {

    private static String TAG = "WidgetRemoteViewsFactory";

    @Override
    public RemoteViewsService.RemoteViewsFactory onGetViewFactory(Intent intent) {
        Log.d(TAG, "onGetViewFactory");
        return new WidgetRemoteViewsFactory(this.getApplicationContext(), intent);
    }
}
