package com.newsblur.util;

import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Set;

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;

import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;

public class NotificationUtils {

    private NotificationUtils() {} // util class - no instances

    public static void notifyStories(Cursor stories, Context context) {
        String title = stories.getCount() + " New Stories";
        if (stories.getCount() == 1) title = "1 New Story";

        StringBuilder content = new StringBuilder();
        while (stories.moveToNext()) {
            String feedTitle = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_TITLE));
            content.append(feedTitle);
            if (! stories.isLast()) {
                content.append(", ");
            }
        }

        Intent appIntent = new Intent(context, Main.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, appIntent, 0);

        Notification n = new Notification.Builder(context)
            .setContentTitle(title)
            .setContentText(content.toString())
            .setSmallIcon(R.drawable.logo_monochrome)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setNumber(stories.getCount())
            .build();

        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        nm.notify(1, n);

    }

}
