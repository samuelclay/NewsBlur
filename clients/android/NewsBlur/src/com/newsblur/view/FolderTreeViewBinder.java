package com.newsblur.view;

import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.widget.SimpleCursorAdapter.ViewBinder;
import android.text.TextUtils;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.StateFilter;

public class FolderTreeViewBinder implements ViewBinder {

	private StateFilter currentState = StateFilter.SOME;
	private final ImageLoader imageLoader;
	
	public FolderTreeViewBinder(ImageLoader imageLoader) {
		this.imageLoader = imageLoader;
	}

	@Override
	public boolean setViewValue(View view, Cursor cursor, int columnIndex) {
		if (equalsAny(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_FAVICON_URL, DatabaseConstants.SOCIAL_FEED_ICON)) {
			if (cursor.getString(columnIndex) != null) {
				String imageUrl = cursor.getString(columnIndex);
				imageLoader.displayImage(imageUrl, (ImageView)view, false);
			} else {
				Bitmap bitmap = BitmapFactory.decodeResource(view.getContext().getResources(), R.drawable.world);
				((ImageView) view).setImageBitmap(bitmap);
			}
            return true;
		} else if (equalsAny(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_POSITIVE_COUNT, DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT)) {
			int feedPositive = cursor.getInt(columnIndex);
            if (feedPositive < 0) feedPositive = 0;
			if (feedPositive > 0) {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText(Integer.toString(feedPositive));
			} else {
				view.setVisibility(View.GONE);
			}
            return true;
		} else if (equalsAny(cursor.getColumnName(columnIndex), DatabaseConstants.FEED_NEUTRAL_COUNT, DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT)) {
			int feedNeutral = cursor.getInt(columnIndex);
            if (feedNeutral < 0) feedNeutral = 0;
			if (feedNeutral > 0 && currentState != StateFilter.BEST) {
				view.setVisibility(View.VISIBLE);
				((TextView) view).setText(Integer.toString(feedNeutral));
			} else {
				view.setVisibility(View.GONE);
			}
            return true;
		} else {
            String text = cursor.getString(columnIndex);
            if ((text != null) && (view instanceof TextView)) {
                ((TextView) view).setText(text);
                return true;
            }
        }
		return false;
	}

	public void setState(StateFilter selection) {
		currentState = selection;
	}

    private boolean equalsAny(String s, String... args) {
        for (String a : args) {
            if (TextUtils.equals(s, a)) return true;
        }
        return false;
    }

}
