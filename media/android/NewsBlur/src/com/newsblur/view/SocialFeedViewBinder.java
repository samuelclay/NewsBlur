package com.newsblur.view;

import android.content.Context;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.support.v4.widget.SimpleCursorAdapter.ViewBinder;
import android.text.TextUtils;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.activity.NewsBlurApplication;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.AppConstants;
import com.newsblur.util.ImageLoader;

public class SocialFeedViewBinder implements ViewBinder {

	private int currentState = AppConstants.STATE_SOME;
	private ImageLoader imageLoader;
	private Context context;
	
	public SocialFeedViewBinder(final Context context) {
		this.context = context;
		imageLoader = ((NewsBlurApplication) context.getApplicationContext()).getImageLoader();
	}
	
	@Override
	public boolean setViewValue(View view, Cursor cursor, int columnIndex) {
		if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT)) {
			int feedPositive = cursor.getInt(columnIndex);
			if (feedPositive > 0) {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText("" + feedPositive);
			} else {
				view.setVisibility(View.GONE);
			}
			return true;
		} else if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT)) {
			int feedNeutral = cursor.getInt(columnIndex);
			if (feedNeutral > 0 && currentState != AppConstants.STATE_BEST) {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText("" + feedNeutral);
			} else {
				view.setVisibility(View.GONE);
			}
			return true;
		} else if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.SOCIAL_FEED_ICON)) {
			String url = cursor.getString(columnIndex);
			imageLoader.displayImage(url, url, (ImageView) view);
			return true;
		} else if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT)) {
			int feedNegative = cursor.getInt(columnIndex);
			if (feedNegative > 0 && currentState == AppConstants.STATE_ALL) {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText("" + feedNegative);
			} else {
				view.setVisibility(View.GONE);
			}
			return true;
		} 

		return false;
	}

	public void setState(int selection) {
		currentState = selection;
	}

}
