package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;

import java.util.Comparator;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class StarredCount {

    public static final String TOTAL_STARRED = "___TOTAL_STARRED";

	@SerializedName("count")
	public int count;

	@SerializedName("tag")
	public String tag;

	@SerializedName("feed_id")
	public String feedId;

    // not vended via the API, but populated by us so we can sort
    public String feedTitle;

	public ContentValues getValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.STARREDCOUNTS_COUNT, count);
		values.put(DatabaseConstants.STARREDCOUNTS_TAG, tag);
		values.put(DatabaseConstants.STARREDCOUNTS_FEEDID, feedId);
		return values;
	}

	public static StarredCount fromCursor(Cursor cursor) {
		if (cursor.isBeforeFirst()) {
			cursor.moveToFirst();
		}
        StarredCount sc = new StarredCount();
        sc.count = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STARREDCOUNTS_COUNT));
        sc.tag = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STARREDCOUNTS_TAG));
        sc.feedId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STARREDCOUNTS_FEEDID));
        return sc;
    }

    public boolean isTotalCount() {
        if (tag == null) return false;
        return tag.equals(TOTAL_STARRED);
    }

    public final static Comparator<StarredCount> StarredCountComparator = new Comparator<StarredCount>() {
        @Override
        public int compare(StarredCount sc1, StarredCount sc2) {
            // tags come before feeds
            if ((sc1.tag != null) && (sc2.feedId != null)) return -1;
            if ((sc2.tag != null) && (sc1.feedId != null)) return 1;
            // then tags are in order
            if ((sc1.tag != null) && (sc2.tag != null)) return String.CASE_INSENSITIVE_ORDER.compare(sc1.tag, sc2.tag);
            // then feeds are in order by name
            if ((sc1.feedTitle != null) && (sc2.feedTitle != null)) return String.CASE_INSENSITIVE_ORDER.compare(sc1.feedTitle, sc2.feedTitle);
            // sensible default if anything is missing
            return String.CASE_INSENSITIVE_ORDER.compare(sc1.feedId, sc2.feedId);
        }
    };

}
