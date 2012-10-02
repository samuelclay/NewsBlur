package com.newsblur.view;

import android.content.Context;
import android.database.Cursor;
import android.support.v4.widget.SimpleCursorAdapter.ViewBinder;
import android.text.Html;
import android.text.TextUtils;
import android.view.View;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;

public class FeedItemViewBinder implements ViewBinder {

	private final Context context;
	private int darkGray;
	private int lightGray;

	public FeedItemViewBinder(final Context context) {
		this.context = context;
		darkGray = context.getResources().getColor(R.color.darkgray);
		lightGray = context.getResources().getColor(R.color.lightgray);
	}
	
	@Override
	public boolean setViewValue(View view, Cursor cursor, int columnIndex) {
		final String columnName = cursor.getColumnName(columnIndex);
		int hasBeenRead = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_READ));
		if (TextUtils.equals(columnName, DatabaseConstants.STORY_READ)) {
			if (hasBeenRead == 0) {
				((TextView) view).setTextColor(darkGray);
				
			} else {
				((TextView) view).setTextColor(lightGray);
			}
			return true;
		} else if (TextUtils.equals(columnName, DatabaseConstants.STORY_AUTHORS)) {
			if (TextUtils.isEmpty(cursor.getString(columnIndex))) {
				view.setVisibility(View.GONE);
			} else {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText(cursor.getString(columnIndex).toUpperCase());
			}
			return true;
		} else if (TextUtils.equals(columnName, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS)) {
			int authors = cursor.getInt(columnIndex);
			
			int tags = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_TAGS));
			int feed = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_FEED));
			int title = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_TITLE));
			if (authors + tags + feed + title > 0) {
				view.setBackgroundResource(hasBeenRead == 0 ? R.drawable.positive_count_circle : R.drawable.positive_count_circle_read);
			} else if (authors + tags + feed + title == 0) {
				view.setBackgroundResource(hasBeenRead == 0 ? R.drawable.neutral_count_circle : R.drawable.neutral_count_circle_read);
			} else {
				view.setBackgroundResource(R.drawable.negative_count_circle);
			}
			
			((TextView) view).setText("");
			return true;
		} else if (TextUtils.equals(columnName, DatabaseConstants.STORY_TITLE)) {
			((TextView) view).setText(Html.fromHtml(cursor.getString(columnIndex)));
			return true;
		}
		
		return false;
	}

}
