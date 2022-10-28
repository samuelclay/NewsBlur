package com.newsblur.widget;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;

import com.newsblur.util.PendingIntentUtils;
import com.newsblur.util.Log;
import com.newsblur.util.PrefsUtils;

public class WidgetUtils {

    private static String TAG = "WidgetUtils";

    public static String ACTION_UPDATE_WIDGET = "ACTION_UPDATE_WIDGET";
    public static String ACTION_OPEN_STORY = "ACTION_OPEN_STORY";
    public static String ACTION_OPEN_CONFIG = "ACTION_OPEN_CONFIG";
    public static String EXTRA_ITEM_ID = "EXTRA_ITEM_ID";
    public static int RC_WIDGET_UPDATE = 1;
    public static int RC_WIDGET_STORY = 2;
    public static int RC_WIDGET_CONFIG = 3;
    public static int STORIES_LIMIT = 5;

    static void enableWidgetUpdate(Context context) {
        Log.d(TAG, "enableWidgetUpdate");
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        Intent intent = getUpdateIntent(context);
        PendingIntent pendingIntent = PendingIntentUtils.getImmutableBroadcast(context, RC_WIDGET_UPDATE, intent, PendingIntent.FLAG_UPDATE_CURRENT);

        int widgetUpdateInterval = 1000 * 60 * 5;
        long startAlarmAt = SystemClock.currentThreadTimeMillis() + widgetUpdateInterval;
        alarmManager.setInexactRepeating(AlarmManager.RTC, startAlarmAt, widgetUpdateInterval, pendingIntent);
    }

    public static void disableWidgetUpdate(Context context) {
        Log.d(TAG, "disableWidgetUpdate");
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        PendingIntent pendingIntent = PendingIntentUtils.getImmutableBroadcast(context, RC_WIDGET_UPDATE, getUpdateIntent(context), PendingIntent.FLAG_UPDATE_CURRENT);
        alarmManager.cancel(pendingIntent);
    }

    public static void resetWidgetUpdate(Context context) {
        if (hasActiveAppWidgets(context)) {
            WidgetUtils.enableWidgetUpdate(context);
        }
    }

    public static boolean hasActiveAppWidgets(Context context) {
        AppWidgetManager widgetManager = AppWidgetManager.getInstance(context);
        int[] appWidgetIds = widgetManager.getAppWidgetIds(new ComponentName(context, WidgetProvider.class));
        return appWidgetIds.length > 0;
    }

    public static boolean isLoggedIn(Context context) {
        return PrefsUtils.getUniqueLoginKey(context) != null;
    }

    public static void updateWidget(Context context) {
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        int[] appWidgetIds = appWidgetManager.getAppWidgetIds(new ComponentName(context, WidgetProvider.class));
        Intent intent = new Intent(context, WidgetProvider.class);
        intent.setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE);
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds);
        context.sendBroadcast(intent);
    }

    public static void checkWidgetUpdateAlarm(Context context) {
        boolean hasActiveUpdates = PendingIntentUtils.getImmutableBroadcast(context, RC_WIDGET_UPDATE, getUpdateIntent(context), PendingIntent.FLAG_NO_CREATE) != null;
        if (!hasActiveUpdates) {
            enableWidgetUpdate(context);
        }
    }

    private static Intent getUpdateIntent(Context context) {
        Intent intent = new Intent(context, WidgetUpdateReceiver.class);
        intent.setAction(ACTION_UPDATE_WIDGET);
        return intent;
    }
}
