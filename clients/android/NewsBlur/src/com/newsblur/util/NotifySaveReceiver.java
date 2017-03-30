package com.newsblur.util;

import com.newsblur.activity.Reading;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;

public class NotifySaveReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(final Context c, final Intent i) {
        final String storyHash = i.getStringExtra(Reading.EXTRA_STORY_HASH);
        NotificationUtils.cancel(c, storyHash.hashCode());
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                FeedUtils.offerInitContext(c);
                FeedUtils.dbHelper.putStoryDismissed(storyHash);
                FeedUtils.setStorySaved(storyHash, true, c);
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

}
