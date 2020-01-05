package com.newsblur.widget;

import android.app.AlertDialog;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.DialogInterface;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.content.Loader;
import android.widget.RemoteViews;

import com.newsblur.R;
import com.newsblur.activity.NbActivity;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.network.APIManager;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.Log;
import com.newsblur.util.PrefsUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

public class ConfigureWidgetActivity extends NbActivity {

    private int appWidgetId;
    private List<Feed> feeds = new ArrayList<>();
    private List<Folder> folders = new ArrayList<>();
    private static String TAG = "ConfigureWidgetActivity";
    private Feed selectedFeed = null;
    private Folder selectedFolder = null;

    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        setContentView(R.layout.activity_configure_widget);
        PrefsUtils.applyThemePreference(this);
        Intent intent = getIntent();
        Bundle extras = intent.getExtras();
        if (extras != null) {
            appWidgetId = extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID);
        }

        PrefsUtils.removeWidgetFeed(this, appWidgetId);

        folders = null;
        feeds = null;
        getAllFeeds();
        getAllFolders();
        // set result as cancelled in the case that we don't finish config
        Intent resultValue = new Intent();
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        setResult(RESULT_CANCELED, resultValue);
    }

    private void getAllFeeds() {
        Loader<Cursor> loader = FeedUtils.dbHelper.getFeedsLoader();
        loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
            @Override
            public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor data) {
                processFeeds(data);
            }
        });
        loader.startLoading();
    }

    private void getAllFolders() {
        Loader<Cursor> loader = FeedUtils.dbHelper.getFoldersLoader();
        loader.registerListener(loader.getId(), new Loader.OnLoadCompleteListener<Cursor>() {
            @Override
            public void onLoadComplete(@NonNull Loader<Cursor> loader, @Nullable Cursor data) {
                processFolders(data);
            }
        });
        loader.startLoading();
    }

    private void processFolders(Cursor cursor) {
        List<Folder> folders = new ArrayList<>();
        while (cursor.moveToNext()) {
            Folder f = Folder.fromCursor(cursor);
            folders.add(f);
        }
        Collections.sort(folders, new Comparator<Folder>() {
            @Override
            public int compare(Folder o1, Folder o2) {
                return o1.name.compareTo(o2.name);
            }
        });
        this.folders = new ArrayList<>();
        this.folders.addAll(folders);
        requestFeedFromUser();
    }

    private void processFeeds(Cursor cursor) {
        List<Feed> feeds = new ArrayList<>();
        while (cursor.moveToNext()) {
            Feed f = Feed.fromCursor(cursor);
            if (f.active) {
                feeds.add(f);
            }
        }
        this.feeds = new ArrayList<>();
        this.feeds.addAll(feeds);
        requestFeedFromUser();
    }

    private void requestFeedFromUser() {
        if (feeds == null || folders == null) {
            return;
        }
        ArrayList<String> feedTitles = new ArrayList<>();
        for (Folder folder : folders) {
            feedTitles.add(String.format("Folder: %s", folder.name));
        }
        for (Feed feed : feeds) {
            feedTitles.add(String.format("Feed: %s", feed.title));
        }
        AlertDialog.Builder builder = new AlertDialog.Builder(this)
                .setTitle("Select a feed")
                .setItems(feedTitles.toArray(new String[feedTitles.size()]), new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        Log.d(TAG, "Selected " + which);
                        if (which < folders.size()) {
                            selectedFolder = folders.get(which);
                        } else {
                            selectedFeed = feeds.get(which);
                        }
                        saveWidget();
                    }
                });
        builder.create().show();
    }

    private void saveWidget() {
        if (selectedFeed == null && selectedFolder == null) {
            toastError("Please select a feed");
            return;
        }
        //update widget
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(this);
        RemoteViews rv = new RemoteViews(getPackageName(),
                R.layout.newsblur_widget);

        Intent intent = new Intent(this, BlurWidgetRemoteViewsService.class);
        // Add the app widget ID to the intent extras.
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        intent.setData(Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME)));

        String title;
        if (selectedFeed != null) {
            PrefsUtils.setWidgetFeed(this, appWidgetId, selectedFeed.feedId, selectedFeed.title);
            title = selectedFeed.title;
        } else {
            PrefsUtils.setWidgetFolderName(this, appWidgetId, selectedFolder.name);
            title = selectedFolder.name;
        }

        rv.setTextViewText(R.id.txt_feed_name, title);
        rv.setRemoteAdapter(R.id.widget_list, intent);
        rv.setEmptyView(R.id.widget_list, R.id.empty_view);


        Intent touchIntent = new Intent(this, NewsBlurWidgetProvider.class);
        // Set the action for the intent.
        // When the user touches a particular view, it will have the effect of
        // broadcasting TOAST_ACTION.
        touchIntent.setAction(NewsBlurWidgetProvider.ACTION_OPEN_STORY);
        touchIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        intent.setData(Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME)));
        PendingIntent touchIntentTemplate = PendingIntent.getBroadcast(this, 0, touchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT);
        rv.setPendingIntentTemplate(R.id.widget_list, touchIntentTemplate);



        appWidgetManager.updateAppWidget(appWidgetId, rv);

        Intent resultValue = new Intent();
        resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId);
        setResult(RESULT_OK, resultValue);
        finish();

    }
}
