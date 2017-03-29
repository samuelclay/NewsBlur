package com.newsblur.util;

import com.newsblur.activity.Reading;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class NotifyMarkreadReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context c, Intent i) {
        String storyHash = i.getStringExtra(Reading.EXTRA_STORY_HASH);
        FeedUtils.offerInitContext(c);
        FeedUtils.dbHelper.putStoryDismissed(storyHash);
        FeedUtils.setStoryReadStateExternal(storyHash, c, true);
    }

}
