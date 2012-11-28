package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import com.newsblur.database.DatabaseConstants;

public class OfflineUpdate {
	
	public int id;
	public UpdateType type;
	public String[] arguments;
	
	public ContentValues getContentValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.UPDATE_ARGUMENTS, TextUtils.join(",", arguments));
		values.put(DatabaseConstants.UPDATE_TYPE, type.name());
		return values;
	}
	
	public static OfflineUpdate fromCursor(final Cursor cursor) {
		OfflineUpdate update = new OfflineUpdate();
		update.arguments = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.UPDATE_ARGUMENTS)), ",");
		update.type = UpdateType.valueOf(cursor.getString(cursor.getColumnIndex(DatabaseConstants.UPDATE_TYPE)));
		update.id = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.UPDATE_ID));
		return update;
	}
	
	public static enum UpdateType { MARK_FEED_AS_READ };
}
