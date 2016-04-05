package com.newsblur.view;

import android.content.Context;
import android.database.Cursor;
import android.graphics.drawable.Drawable;
import android.widget.SimpleCursorAdapter.ViewBinder;
import android.text.Html;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.StoryUtils;

import java.util.Date;

public class FeedItemViewBinder implements ViewBinder {

	private final Context context;
    private boolean ignoreIntel;

	public FeedItemViewBinder(Context context, boolean ignoreIntel) {
		this.context = context;
        this.ignoreIntel = ignoreIntel;
	}

	public FeedItemViewBinder(Context context) {
        this(context, false);
    }
	
	@Override
	public boolean setViewValue(View view, Cursor cursor, int columnIndex) {
		final String columnName = cursor.getColumnName(columnIndex);
		if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_FAVICON_URL)) {
			String faviconUrl = cursor.getString(columnIndex);
			FeedUtils.imageLoader.displayImage(faviconUrl, ((ImageView) view), true);
			return true;
		} else if (TextUtils.equals(columnName, DatabaseConstants.STORY_AUTHORS)) {
			if (TextUtils.isEmpty(cursor.getString(columnIndex))) {
				view.setVisibility(View.GONE);
			} else {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText(cursor.getString(columnIndex).toUpperCase());
			}
			return true;
		} else if (TextUtils.equals(columnName, DatabaseConstants.STORY_INTELLIGENCE_TOTAL)) {
            if (! this.ignoreIntel) {
                int hasBeenRead = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_READ));
                int score = cursor.getInt(columnIndex);
                Drawable icon;
                if (score > 0) {
                    icon = view.getResources().getDrawable(R.drawable.g_icn_focus);
                } else if (score == 0) {
                    icon = view.getResources().getDrawable(R.drawable.g_icn_unread);
                } else {
                    icon = view.getResources().getDrawable(R.drawable.g_icn_hidden);
                }
                icon.mutate().setAlpha(hasBeenRead == 0 ? 255 : 127);
                view.setBackgroundDrawable(icon);
            } else {
                view.setBackgroundDrawable(null);
            }
			return true;
		} else if (TextUtils.equals(columnName, DatabaseConstants.STORY_TITLE)) {
            ((TextView) view).setText(Html.fromHtml(cursor.getString(columnIndex)));
			return true;
		} else if (TextUtils.equals(columnName, DatabaseConstants.STORY_TIMESTAMP)) {
            ((TextView) view).setText(StoryUtils.formatShortDate(context, new Date(cursor.getLong(columnIndex))));
            return true;
        }
		
		return false;
	}

}
