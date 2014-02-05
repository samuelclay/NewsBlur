package com.newsblur.util;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;

/**
 * Created by mark on 04/02/2014.
 */
public class StoryUtils {

    private static final SimpleDateFormat todayLongFormat = new SimpleDateFormat("MMMM d");
    private static final SimpleDateFormat monthLongFormat = new SimpleDateFormat("EEEE, MMMM d");
    private static final SimpleDateFormat yearLongFormat = new SimpleDateFormat("yyyy");
    private static final SimpleDateFormat twelveHourFormat = new SimpleDateFormat("h:mma");

    public static String formatLongDate(Date storyDate) {

        Date midnightToday = midnightToday();
        Date midnightYesterday = midnightYesterday();
        Date beginningOfMonth = beginningOfMonth();

        Calendar storyCalendar = Calendar.getInstance();
        storyCalendar.setTime(storyDate);
        int month = storyCalendar.get(Calendar.DAY_OF_MONTH);

        // F = Long Month
        // l = Long Day
        // j = day number
        // S = st/th etc.
        if (storyDate.getTime() > midnightToday.getTime()) {
            // Today, January 1st 00:00
            return "Today, " + todayLongFormat.format(storyDate) + getDayOfMonthSuffix(month) + " " + twelveHourFormat.format(storyDate);
        } else if (storyDate.getTime() > midnightYesterday.getTime()) {
            // Yesterday, January 1st 00:00
            return "Yesterday, " + todayLongFormat.format(storyDate) + getDayOfMonthSuffix(month) + " " + twelveHourFormat.format(storyDate);
        } else if (storyDate.getTime() > beginningOfMonth.getTime()) {
            // Monday, January 1st 00:00
            return monthLongFormat.format(storyDate) + getDayOfMonthSuffix(month) + " " + twelveHourFormat.format(storyDate);
        } else {
            // Monday, January 1st 2014 00:00
            return monthLongFormat.format(storyDate) + getDayOfMonthSuffix(month) + " " + yearLongFormat.format(storyDate) + " " + twelveHourFormat.format(storyDate);
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
}
