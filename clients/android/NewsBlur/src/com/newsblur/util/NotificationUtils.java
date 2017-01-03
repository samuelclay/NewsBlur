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
import com.newsblur.util.FileCache;

public class NotificationUtils {

    private NotificationUtils() {} // util class - no instances

    public static void notifyStories(Cursor stories, Context context) {
        ;
    }

}
