package com.newsblur.widget;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;

import com.newsblur.R;
import com.newsblur.util.Log;

public class WidgetUtils {

    private static String TAG = "WidgetUtils";

    public static String ACTION_UPDATE_WIDGET = "ACTION_UPDATE_WIDGET";
    public static String ACTION_OPEN_STORY = "ACTION_OPEN_STORY";
    public static String EXTRA_ITEM_ID = "EXTRA_ITEM_ID";
    public static String EXTRA_FEED_ID = "EXTRA_FEED_ID";
    public static int RC_WIDGET_UPDATE = 1;

    static void setUpdateAlarm(Context context) {
        Log.d(TAG, "setUpdateAlarm");
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        Intent intent = getUpdateIntent(context);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(context, RC_WIDGET_UPDATE, intent, PendingIntent.FLAG_UPDATE_CURRENT);

        int widgetUpdateInterval = 1000 * 60 * 5;
        long startAlarmAt = SystemClock.currentThreadTimeMillis() + widgetUpdateInterval;
        alarmManager.setInexactRepeating(AlarmManager.RTC, startAlarmAt, widgetUpdateInterval, pendingIntent);
    }

    static void removeUpdateAlarm(Context context) {
        Log.d(TAG, "removeUpdateAlarm");
        if (!hasActiveAppWidgets(context)) {
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            PendingIntent pendingIntent = PendingIntent.getBroadcast(context, RC_WIDGET_UPDATE, getUpdateIntent(context), PendingIntent.FLAG_UPDATE_CURRENT);
            alarmManager.cancel(pendingIntent);
        }
    }

    public static void resetUpdateAlarm(Context context) {
        if (hasActiveAppWidgets(context)) {
            WidgetUtils.setUpdateAlarm(context);
        }
    }

    public static boolean hasActiveAppWidgets(Context context) {
        AppWidgetManager widgetManager = AppWidgetManager.getInstance(context);
        int[] appWidgetIds = widgetManager.getAppWidgetIds(new ComponentName(context, WidgetProvider.class));
        return appWidgetIds.length > 0;
    }

    public static void notifyViewDataChanged(Context context) {
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        int[] appWidgetIds = appWidgetManager.getAppWidgetIds(new ComponentName(context, WidgetProvider.class));
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list);
    }

    private static Intent getUpdateIntent(Context context) {
        Intent intent = new Intent(context, WidgetUpdateReceiver.class);
        intent.setAction(ACTION_UPDATE_WIDGET);
        return intent;
    }
}
