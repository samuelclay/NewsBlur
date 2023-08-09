package com.newsblur.widget

import android.content.Intent
import android.widget.RemoteViewsService
import com.newsblur.util.Log

class WidgetRemoteViewsService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
            WidgetRemoteViewsFactory(this.applicationContext, intent).also {
                Log.d("WidgetRemoteViewsFactory", "onGetViewFactory")
            }
}