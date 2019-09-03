package com.newsblur.widget;

import android.app.AlertDialog;
import android.appwidget.AppWidgetManager;
import android.content.DialogInterface;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.content.Loader;
import android.view.View;
import android.widget.Button;
import android.widget.RemoteViews;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.domain.Feed;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.Log;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class ConfigureWidgetActivity extends NbActivity {
    private int appWidgetId;
    private ExecutorService executorService;
    private List<Feed> feeds = new ArrayList<>();
    private static String TAG = "ConfigureWidgetActivity";
    private Feed selectedFeed = null;
    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        setContentView(R.layout.activity_configure_widget);

        Intent intent = getIntent();
        Bundle extras = intent.getExtras();
        if (extras != null) {
            appWidgetId = extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID);
        }


        Button btnSelect = findViewById(R.id.btn_select);
        btnSelect.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                getAllFeeds();
            }
        });
        Button btnSaveWidget = findViewById(R.id.btn_save);
        btnSaveWidget.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                saveWidget();
            }
        });

        // set result as cancelled in the case that we don't finish config
        Intent resultValue = new Intent();
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        setResult(RESULT_CANCELED, resultValue);
    }

    private void getAllFeeds(){
        Loader<Cursor> loader = FeedUtils.dbHelper.getFeedsLoader();
        loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
            @Override
            public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor data) {
                processFeeds(data);
            }
        });
        loader.startLoading();
    }

    private void processFeeds(Cursor cursor) {
        List<Feed> feeds = new ArrayList<>();
        while (cursor.moveToNext()) {
            Feed f = Feed.fromCursor(cursor);
            if (f.active) {
                feeds.add(f);
            }
        }
        this.feeds.clear();
        this.feeds.addAll(feeds);
        requestFeedFromUser();
    }

    private void requestFeedFromUser(){
        ArrayList<String> feedTitles = new ArrayList<>();
        for (Feed feed : feeds) {
            feedTitles.add(feed.title);
        }
        AlertDialog.Builder builder = new AlertDialog.Builder(this)
                .setTitle("Select a feed")
                .setItems(feedTitles.toArray(new String[feedTitles.size()]), new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        Log.d(TAG, "Clicked " + which);
                        selectedFeed = feeds.get(which);
                    }
                });
        builder.create().show();
    }


    private void saveWidget(){
        if (selectedFeed == null) {
            toastError("Please select a feed");
            return;
        }
        //update widget
        Log.d(TAG, "saveWidget");
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(this);
        RemoteViews rv = new RemoteViews(getPackageName(),
                R.layout.newsblur_widget);

        Intent intent = new Intent(this, BlurWidgetRemoteViewsService.class);
        // Add the app widget ID to the intent extras.
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        intent.putExtra(BlurWidgetRemoteViewsService.EXTRA_FEED_ID, selectedFeed.feedId);

        rv.setRemoteAdapter(R.id.widget_list, intent);
        rv.setEmptyView(R.id.widget_list, R.id.empty_view);

        appWidgetManager.updateAppWidget(appWidgetId, rv);


        Intent resultValue = new Intent();
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        setResult(RESULT_OK, resultValue);
        finish();
    }
}
