package com.newsblur.view;

import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.text.TextUtils;
import android.util.Base64;
import android.view.View;
import android.widget.ImageView;
import android.widget.SimpleCursorTreeAdapter.ViewBinder;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.AppConstants;

public class FolderTreeViewBinder implements ViewBinder {

	private int currentState = AppConstants.STATE_SOME;
	
	@Override
	public boolean setViewValue(View view, Cursor cursor, int columnIndex) {
		if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_FAVICON)) {
			Bitmap bitmap = null;
			if (cursor.getBlob(columnIndex) != null) {
				final byte[] data = Base64.decode(cursor.getBlob(columnIndex), Base64.DEFAULT);
				bitmap = BitmapFactory.decodeByteArray(data, 0, data.length);
			}
			if (bitmap == null) {
				bitmap = BitmapFactory.decodeResource(view.getContext().getResources(), R.drawable.no_favicon);
			}
			((ImageView) view).setImageBitmap(bitmap);
			return true;
		} else if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_POSITIVE_COUNT) || TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.SUM_POS)) {
			int feedPositive = cursor.getInt(columnIndex);
			if (feedPositive > 0) {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText("" + feedPositive);
			} else {
				view.setVisibility(View.GONE);
			}
			return true;
		} else if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_NEUTRAL_COUNT) || TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.SUM_NEUT)) {
			int feedNeutral = cursor.getInt(columnIndex);
			if (feedNeutral > 0 && currentState != AppConstants.STATE_BEST) {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText("" + feedNeutral);
			} else {
				view.setVisibility(View.GONE);
			}
			return true;
		} else if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_NEGATIVE_COUNT) || TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.SUM_NEG)) {
			int feedNegative = cursor.getInt(columnIndex);
			if (feedNegative > 0 && currentState == AppConstants.STATE_ALL) {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText("" + feedNegative);
			} else {
				view.setVisibility(View.GONE);
			}
			return true;
		} else if (TextUtils.equals(cursor.getColumnName(columnIndex), DatabaseConstants.FOLDER_NAME)) {
			String folderName = cursor.getString(columnIndex);
			if (!TextUtils.equals(folderName, "Unsorted")) {
				folderName = folderName.toUpperCase();
			}
			((TextView) view).setText("" + folderName);
			return true;
		}

		return false;
	}

	public void setState(int selection) {
		currentState = selection;
	}

}
