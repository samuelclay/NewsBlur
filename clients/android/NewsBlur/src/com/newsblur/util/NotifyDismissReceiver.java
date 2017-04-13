package com.newsblur.util;

import com.newsblur.activity.Reading;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;

public class NotifyDismissReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(final Context c, final Intent i) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                String storyHash = i.getStringExtra(Reading.EXTRA_STORY_HASH);
                FeedUtils.offerInitContext(c);
                FeedUtils.dbHelper.putStoryDismissed(storyHash);
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

}
