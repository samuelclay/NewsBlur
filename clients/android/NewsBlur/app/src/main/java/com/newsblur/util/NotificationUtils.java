package com.newsblur.util;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.StatusBarNotification;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.fragment.app.Fragment;

import com.newsblur.R;
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.Reading;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.domain.Story;

import java.util.ArrayList;
import java.util.List;

public class NotificationUtils {

    private static final int NOTIFY_COLOUR = 0xFFDA8A35;
    private static final int MAX_CONCUR_NOTIFY = 5;

    private NotificationUtils() {
    } // util class - no instances

    /**
     * @param storiesFocus  a cursor of unread, focus stories to notify, ordered newest to oldest
     * @param storiesUnread a cursor of unread, neutral stories to notify, ordered newest to oldest
     */
    public static synchronized void notifyStories(Context context, Cursor storiesFocus, Cursor storiesUnread, FileCache iconCache, BlurDatabaseHelper dbHelper) {
        NotificationManagerCompat nm = NotificationManagerCompat.from(context);

        int count = 0;
        while (storiesFocus.moveToNext()) {
            Story story = Story.fromCursor(storiesFocus);
            if (story.read) {
                nm.cancel(story.hashCode());
                continue;
            }
            if (dbHelper.isStoryDismissed(story.storyHash)) {
                nm.cancel(story.hashCode());
                continue;
            }
            if (StoryUtils.hasOldTimestamp(story.timestamp)) {
                dbHelper.putStoryDismissed(story.storyHash);
                nm.cancel(story.hashCode());
                continue;
            }
            if (count < MAX_CONCUR_NOTIFY) {
                Notification n = buildStoryNotification(story, storiesFocus, context, iconCache);
                nm.notify(story.hashCode(), n);
            } else {
                nm.cancel(story.hashCode());
                dbHelper.putStoryDismissed(story.storyHash);
            }
            count++;
        }
        while (storiesUnread.moveToNext()) {
            Story story = Story.fromCursor(storiesUnread);
            if (story.read) {
                nm.cancel(story.hashCode());
                continue;
            }
            if (dbHelper.isStoryDismissed(story.storyHash)) {
                nm.cancel(story.hashCode());
                continue;
            }
            if (StoryUtils.hasOldTimestamp(story.timestamp)) {
                dbHelper.putStoryDismissed(story.storyHash);
                nm.cancel(story.hashCode());
                continue;
            }
            if (count < MAX_CONCUR_NOTIFY) {
                Notification n = buildStoryNotification(story, storiesUnread, context, iconCache);
                nm.notify(story.hashCode(), n);
            } else {
                nm.cancel(story.hashCode());
                dbHelper.putStoryDismissed(story.storyHash);
            }
            count++;
        }
    }

    /**
     * NotificationUtils.java: posts the one story a push named (StoryPush.kt). The server already chose it for this
     * device, so the feed filter of the notify queries is not applied again. Read, dismissed and old stories are
     * still left out, exactly as notifyStories leaves them out.
     */
    public static synchronized void notifyPushedStory(Context context, BlurDatabaseHelper dbHelper, FileCache iconCache, String storyHash) {
        NotificationManagerCompat nm = NotificationManagerCompat.from(context);
        Cursor cursor = dbHelper.getNotifyPushedStoryCursor(storyHash);
        try {
            if (cursor == null || !cursor.moveToFirst()) return;
            Story story = Story.fromCursor(cursor);
            if (story.read || dbHelper.isStoryDismissed(story.storyHash)) {
                nm.cancel(story.hashCode());
            } else if (StoryUtils.hasOldTimestamp(story.timestamp)) {
                dbHelper.putStoryDismissed(story.storyHash);
                nm.cancel(story.hashCode());
            } else if (makeRoomFor(story, context, nm, dbHelper)) {
                nm.notify(story.hashCode(), buildStoryNotification(story, cursor, context, iconCache));
            }
        } finally {
            BlurDatabaseHelper.closeQuietly(cursor);
        }
    }

    /**
     * NotificationUtils.java: notifyStories keeps to MAX_CONCUR_NOTIFY by walking its own list of stories. A pushed
     * story arrives alone, so the oldest stories are dismissed to keep the same limit. Returns false when the
     * pushed story is itself one of the oldest and should not be shown.
     */
    private static boolean makeRoomFor(Story story, Context context, NotificationManagerCompat nm, BlurDatabaseHelper dbHelper) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        List<StoryNotificationLimit.Showing> showing = new ArrayList<>();
        for (StatusBarNotification active : manager.getActiveNotifications()) {
            // Only story notifications carry this extra; the Listen player and group summaries do not.
            String storyHash = active.getNotification().extras.getString(Reading.EXTRA_STORY_HASH);
            if (storyHash != null && active.getId() != story.hashCode()) {
                showing.add(new StoryNotificationLimit.Showing(active.getId(), active.getNotification().when, storyHash));
            }
        }
        StoryNotificationLimit.Showing incoming = new StoryNotificationLimit.Showing(story.hashCode(), story.timestamp, story.storyHash);
        boolean hasRoom = true;
        for (StoryNotificationLimit.Showing oldest : StoryNotificationLimit.toDismiss(showing, incoming, MAX_CONCUR_NOTIFY)) {
            nm.cancel(oldest.getId());
            dbHelper.putStoryDismissed(oldest.getStoryHash());
            if (oldest.getId() == incoming.getId()) hasRoom = false;
        }
        return hasRoom;
    }

    /**
     * creates notification channels necessary for 26+, if applicable
     */
    public static void createNotificationChannel(Context context) {
        // NotificationUtils.java names the channel in the app language, which Android shows in notification settings.
        CharSequence name = LanguageSettings.INSTANCE.localizedContext(context).getString(R.string.story_notification_channel_name);
        String id = context.getString(R.string.story_notification_channel_id);
        NotificationChannel channel = new NotificationChannel(id, name, NotificationManager.IMPORTANCE_DEFAULT);

        NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
        notificationManager.createNotificationChannel(channel);
    }

    private static Notification buildStoryNotification(Story story, Cursor cursor, Context context, FileCache iconCache) {
        Log.d(NotificationUtils.class.getName(), "Building notification");
        Intent i = new Intent(context, FeedReading.class);
        // the action is unused, but bugs in some platform versions ignore extras if it is unset
        i.setAction(story.storyHash);
        // these extras actually dictate activity behaviour
        i.putExtra(Reading.EXTRA_FEEDSET, FeedSet.singleFeed(story.feedId));
        i.putExtra(Reading.EXTRA_STORY_HASH, story.storyHash);
        // force a new Reading activity, since if multiple notifications are tapped, any re-use or
        // stacking of the activity would almost certainly out-race the sync loop and cause stale
        // UI on some devices.
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        // set the requestCode to the story hashcode to prevent the PI re-using the wrong Intent
        PendingIntent pendingIntent = PendingIntentUtils.getImmutableActivity(context, story.hashCode(), i, PendingIntent.FLAG_UPDATE_CURRENT);

        Intent dismissIntent = new Intent(context, NotifyDismissReceiver.class);
        dismissIntent.putExtra(Reading.EXTRA_STORY_HASH, story.storyHash);
        PendingIntent dismissPendingIntent = PendingIntentUtils.getImmutableBroadcast(context.getApplicationContext(), story.hashCode(), dismissIntent, 0);

        Intent saveIntent = new Intent(context, NotifySaveReceiver.class);
        saveIntent.putExtra(Reading.EXTRA_STORY_HASH, story.storyHash);
        PendingIntent savePendingIntent = PendingIntentUtils.getImmutableBroadcast(context.getApplicationContext(), story.hashCode(), saveIntent, 0);

        Intent markreadIntent = new Intent(context, NotifyMarkreadReceiver.class);
        markreadIntent.putExtra(Reading.EXTRA_STORY_HASH, story.storyHash);
        PendingIntent markreadPendingIntent = PendingIntentUtils.getImmutableBroadcast(context.getApplicationContext(), story.hashCode(), markreadIntent, 0);

        Intent shareIntent = new Intent(context, NotifyShareReceiver.class);
        shareIntent.putExtra(Reading.EXTRA_STORY, story);
        PendingIntent sharePendingIntent = PendingIntentUtils.getImmutableBroadcast(context.getApplicationContext(), story.hashCode(), shareIntent, 0);

        String feedTitle = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_TITLE));
        StringBuilder title = new StringBuilder();
        title.append(feedTitle).append(": ").append(story.title);

        String faviconUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
        Bitmap feedIcon = ImageLoader.getCachedImageSynchro(iconCache, faviconUrl);

        // NotificationUtils.java often runs from SyncService.kt with no activity, so it resolves labels in the app language explicitly.
        Context strings = LanguageSettings.INSTANCE.localizedContext(context);
        NotificationCompat.Builder nb = new NotificationCompat.Builder(context, context.getString(R.string.story_notification_channel_id))
                .setContentTitle(title.toString())
                .setContentText(story.shortContent)
                .setSmallIcon(R.drawable.logo_monochrome)
                .setContentIntent(pendingIntent)
                .setDeleteIntent(dismissPendingIntent)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setWhen(story.timestamp)
                .addAction(0, strings.getString(R.string.menu_mark_story_as_read), markreadPendingIntent)
                .addAction(0, strings.getString(R.string.save_this), savePendingIntent)
                .addAction(0, strings.getString(R.string.share_this), sharePendingIntent)
                .setColor(NOTIFY_COLOUR);
        // NotificationUtils.java reads this back from the notifications showing, to know which stories they are.
        Bundle extras = new Bundle();
        extras.putString(Reading.EXTRA_STORY_HASH, story.storyHash);
        nb.addExtras(extras);
        if (feedIcon != null) {
            nb.setLargeIcon(feedIcon);
        }

        return nb.build();
    }

    public static void clear(Context context) {
        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        nm.cancelAll();
    }

    public static void cancel(Context context, int nid) {
        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        nm.cancel(nid);
    }

    public static boolean hasPermissions(Context context) {
        if (Build.VERSION.SDK_INT >= 33) {
            return context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
        } else return true;
    }

    public static boolean shouldShowRationale(Fragment fragment) {
        if (Build.VERSION.SDK_INT >= 33) {
            return fragment.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS);
        } else return false;
    }
}
