package com.newsblur.widget

import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.newsblur.NbApplication
import com.newsblur.util.Log

class WidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        // WidgetRemoteViewsService.kt can start with a plain Application during restricted backup.
        // Leave widget settings untouched until a normal NbApplication process binds again.
        if (applicationContext !is NbApplication) return RestrictedStartupFactory
        return WidgetRemoteViewsFactory(applicationContext, intent).also {
            Log.d("WidgetRemoteViewsFactory", "onGetViewFactory")
        }
    }

    private object RestrictedStartupFactory : RemoteViewsFactory {
        override fun onCreate() = Unit
        override fun onDataSetChanged() = Unit
        override fun onDestroy() = Unit
        override fun getCount(): Int = 0
        override fun getViewAt(position: Int): RemoteViews? = null
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount(): Int = 1
        override fun getItemId(position: Int): Long = position.toLong()
        override fun hasStableIds(): Boolean = true
    }
}
