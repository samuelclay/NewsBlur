package com.newsblur.util;

import android.content.Context;
import android.text.format.DateFormat;
import android.text.format.DateUtils;

import java.text.DateFormatSymbols;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

/**
 * Created by mark on 04/02/2014.
 */
public class StoryUtils {

    private StoryUtils() {} // util class - no instances

    private static final ThreadLocal<SimpleDateFormat> todayLongFormat = new ThreadLocal<SimpleDateFormat>() {
        @Override
        protected SimpleDateFormat initialValue() {
            return new SimpleDateFormat("MMMM d");
        }
    };

    private static final ThreadLocal<SimpleDateFormat> monthLongFormat = new ThreadLocal<SimpleDateFormat>() {
        @Override
        protected SimpleDateFormat initialValue() {
            return new SimpleDateFormat("EEEE, MMMM d");
        }
    };

    private static final ThreadLocal<SimpleDateFormat> yearLongFormat = new ThreadLocal<SimpleDateFormat>() {
        @Override
        protected SimpleDateFormat initialValue() {
            return new SimpleDateFormat("yyyy");
        }
    };

    private static final ThreadLocal<SimpleDateFormat> twelveHourFormat = new ThreadLocal<SimpleDateFormat>() {
        @Override
        protected SimpleDateFormat initialValue() {
            SimpleDateFormat sdf = new SimpleDateFormat("h:mma");
            DateFormatSymbols dfs = new DateFormatSymbols();
            dfs.setAmPmStrings(new String[] { "am", "pm" });
            sdf.setDateFormatSymbols(dfs);
            return sdf;
        }
    };

    private static final ThreadLocal<SimpleDateFormat> shortDateFormat = new ThreadLocal<SimpleDateFormat>() {
        @Override
        protected SimpleDateFormat initialValue() {
            return new SimpleDateFormat("d MMM yyyy");
        }
    };

    private static final ThreadLocal<SimpleDateFormat> twentyFourHourFormat = new ThreadLocal<SimpleDateFormat>() {
        @Override
        protected SimpleDateFormat initialValue() {
            return new SimpleDateFormat("HH:mm");
        }
    };

    public static String formatLongDate(Context context, long timestamp) {
        Date storyDate = new Date(timestamp);
        Date midnightToday = midnightToday();
        Date midnightYesterday = midnightYesterday();
        Date beginningOfMonth = beginningOfMonth();

        Calendar storyCalendar = Calendar.getInstance();
        storyCalendar.setTime(storyDate);
        int month = storyCalendar.get(Calendar.DAY_OF_MONTH);

        SimpleDateFormat timeFormat = getTimeFormat(context);
        Locale locale = context.getResources().getConfiguration().locale;

        if(!locale.getLanguage().equals("en")){
            String pattern = null;

            if (storyDate.getTime() > beginningOfMonth.getTime()) {
                // localized pattern, without year
                pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEE MMMM d");
            }else {
                // localized pattern, with year
                pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEE MMMM d yyyy");
            }
            return DateFormat.format(pattern, storyDate).toString() + " " + timeFormat.format(storyDate);
        }

        if (storyDate.getTime() > midnightToday.getTime()) {
            // Today, January 1st 00:00
            return "Today, " + todayLongFormat.get().format(storyDate) + getDayOfMonthSuffix(month) + " " + timeFormat.format(storyDate);
        } else if (storyDate.getTime() > midnightYesterday.getTime()) {
            // Yesterday, January 1st 00:00
            return "Yesterday, " + todayLongFormat.get().format(storyDate) + getDayOfMonthSuffix(month) + " " + timeFormat.format(storyDate);
        } else if (storyDate.getTime() > beginningOfMonth.getTime()) {
            // Monday, January 1st 00:00
            return monthLongFormat.get().format(storyDate) + getDayOfMonthSuffix(month) + " " + timeFormat.format(storyDate);
        } else {
            // Monday, January 1st 2014 00:00
            return monthLongFormat.get().format(storyDate) + getDayOfMonthSuffix(month) + " " + yearLongFormat.get().format(storyDate) + " " + timeFormat.format(storyDate);
        }
    }

    private static Date midnightToday() {
        Calendar midnight = Calendar.getInstance();
        midnight.set(Calendar.HOUR_OF_DAY, 0);
        midnight.set(Calendar.MINUTE, 0);
        midnight.set(Calendar.SECOND, 0);
        return midnight.getTime();
    }

    private static Date midnightYesterday() {
        return new Date(midnightToday().getTime() - (24 * 60 * 60* 1000));
    }

    private static Date beginningOfMonth() {
        Calendar month = Calendar.getInstance();
        month.set(Calendar.HOUR_OF_DAY, 0);
        month.set(Calendar.MINUTE, 0);
        month.set(Calendar.SECOND, 0);
        month.set(Calendar.DAY_OF_MONTH, 1);
        return month.getTime();
    }

    private static SimpleDateFormat getTimeFormat(Context context) {
        if (android.text.format.DateFormat.is24HourFormat(context)) {
            return twentyFourHourFormat.get();
        } else {
            return twelveHourFormat.get();
        }
    }

    /**
     * From http://stackoverflow.com/questions/4011075/how-do-you-format-the-day-of-the-month-to-say-11th-21st-or-23rd-in-java
     */
    private static String getDayOfMonthSuffix(final int n) {
        if (n >= 11 && n <= 13) {
            return "th";
        }
        switch (n % 10) {
            case 1:  return "st";
            case 2:  return "nd";
            case 3:  return "rd";
            default: return "th";
        }
    }

    public static String formatShortDate(Context context, long timestamp) {
        Date storyDate = new Date(timestamp);
        Date midnightToday = midnightToday();
        Date midnightYesterday = midnightYesterday();

        SimpleDateFormat timeFormat = getTimeFormat(context);

        Locale locale = context.getResources().getConfiguration().locale;

        if(!locale.getLanguage().equals("en")){
            if (storyDate.getTime() > midnightToday.getTime()) {
                return timeFormat.format(storyDate);
            }else {
                String pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "d MMM yyyy " + timeFormat.toPattern());
                return DateFormat.format(pattern, storyDate).toString();
            }
        }

        if (storyDate.getTime() > midnightToday.getTime()) {
            // 00:00
            return timeFormat.format(storyDate);
        } else if (storyDate.getTime() > midnightYesterday.getTime()) {
            // Yesterday, 00:00
            return "Yesterday, " + timeFormat.format(storyDate);
        } else {
            // 1 Jan 2014, 00:00
            return shortDateFormat.get().format(storyDate) +", " + timeFormat.format(storyDate);
        }
    }

    public static boolean hasOldTimestamp(long storyTimestamp) {
        return (System.currentTimeMillis() - storyTimestamp) > (2 * DateUtils.DAY_IN_MILLIS);
    }
}
