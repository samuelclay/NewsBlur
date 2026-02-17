package com.newsblur.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import com.newsblur.R
import dagger.hilt.android.EntryPointAccessors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object WidgetUpdater {
    suspend fun updateAll(context: Context) {
        if (Build.VERSION.SDK_INT < 31) return
        val awm = AppWidgetManager.getInstance(context)
        val ids = awm.getAppWidgetIds(ComponentName(context, WidgetProvider::class.java))
        if (ids.isEmpty()) return
        update(context, awm, ids)
    }

    suspend fun update(
        context: Context,
        awm: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        if (Build.VERSION.SDK_INT < 31) return
        withContext(Dispatchers.IO) {
            val ep =
                EntryPointAccessors.fromApplication(
                    context.applicationContext,
                    WidgetRemoteViewsFactoryEntryPoint::class.java,
                )
            val prefsRepo = ep.prefRepository()
            val iconLoader = ep.iconLoader()
            val thumbLoader = ep.thumbnailLoader()
            val storyApi = ep.storyApi()
            val dbHelper = ep.dbHelper()

            if (!WidgetUtils.isLoggedIn(prefsRepo)) return@withContext

            val feedIds = prefsRepo.getWidgetFeedIds()
            val showSetupEmptyText = (feedIds != null && feedIds.isEmpty())

            for (id in appWidgetIds) {
                val root = WidgetRoot.create(context, prefsRepo, id, showSetupEmptyText)
                root.setRemoteAdapter(R.id.widget_list, emptyItems())
                awm.updateAppWidget(id, root)
            }

            val data =
                WidgetRepository.loadForWidget(
                    prefsRepo = prefsRepo,
                    storyApi = storyApi,
                    dbHelper = dbHelper,
                )

            WidgetImage.prefetch(
                context = context,
                prefsRepo = prefsRepo,
                iconLoader = iconLoader,
                thumbnailLoader = thumbLoader,
                stories = data.stories,
            )

            for (id in appWidgetIds) {
                val root = WidgetRoot.create(context, prefsRepo, id, data.showSetupEmptyText)
                root.setRemoteAdapter(R.id.widget_list, buildItems(context, prefsRepo, iconLoader, thumbLoader, data.stories))
                awm.updateAppWidget(id, root)
            }
        }
    }

    @RequiresApi(31)
    private fun buildItems(
        context: Context,
        prefsRepo: com.newsblur.preference.PrefsRepo,
        iconLoader: com.newsblur.util.ImageLoader,
        thumbnailLoader: com.newsblur.util.ImageLoader,
        stories: List<com.newsblur.domain.Story>,
    ): RemoteViews.RemoteCollectionItems {
        val b =
            RemoteViews.RemoteCollectionItems
                .Builder()
                .setViewTypeCount(1)
                .setHasStableIds(true)

        stories.forEach { story ->
            val row = WidgetRow.create(context, prefsRepo, iconLoader, thumbnailLoader, story)
            b.addItem(WidgetRow.id64(story.storyHash), row)
        }

        return b.build()
    }

    @RequiresApi(31)
    private fun emptyItems(): RemoteViews.RemoteCollectionItems =
        RemoteViews.RemoteCollectionItems
            .Builder()
            .setViewTypeCount(1)
            .setHasStableIds(true)
            .build()

    @RequiresApi(31)
    fun updateEmpty(
        context: Context,
        awm: AppWidgetManager,
        appWidgetIds: IntArray,
        showSetupEmptyText: Boolean,
    ) {
        val ep =
            EntryPointAccessors.fromApplication(
                context.applicationContext,
                WidgetRemoteViewsFactoryEntryPoint::class.java,
            )
        val prefsRepo = ep.prefRepository()

        val empty =
            RemoteViews.RemoteCollectionItems
                .Builder()
                .setViewTypeCount(1)
                .setHasStableIds(true)
                .build()

        for (id in appWidgetIds) {
            val root = WidgetRoot.create(context, prefsRepo, id, showSetupEmptyText)
            root.setRemoteAdapter(R.id.widget_list, empty)
            awm.updateAppWidget(id, root)
        }
    }
}
