package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.graphics.Color;
import android.support.v4.widget.SimpleCursorAdapter;
import android.text.TextUtils;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;

import com.newsblur.R;
import com.newsblur.activity.NewsBlurApplication;
import com.newsblur.util.AppConstants;
import com.newsblur.util.ImageLoader;

public class MultipleFeedItemsAdapter extends SimpleCursorAdapter {

	private Cursor cursor;
	private ImageLoader imageLoader;

	public MultipleFeedItemsAdapter(Context context, int layout, Cursor c, String[] from, int[] to, int flags) {
		super(context, layout, c, from, to, flags);
		imageLoader = ((NewsBlurApplication) context.getApplicationContext()).getImageLoader();
		this.cursor = c;
	}

	@Override
	public int getCount() {
		return cursor.getCount();
	}

	@Override
	public Cursor swapCursor(Cursor c) {
		this.cursor = c;
		return super.swapCursor(c);
	}

	@Override
	public View getView(int position, View view, ViewGroup viewGroup) {
		View v = super.getView(position, view, viewGroup);
		View borderOne = v.findViewById(R.id.row_item_favicon_borderbar_1);
		View borderTwo = v.findViewById(R.id.row_item_favicon_borderbar_2);

		cursor.moveToPosition(position);
		String feedColour = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_BORDER));
		String feedFade = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOUR));

		String faviconUrl = AppConstants.NEWSBLUR_URL + cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
		imageLoader.displayImage(faviconUrl, ((ImageView) v.findViewById(R.id.row_item_feedicon)));

		if (!TextUtils.equals(feedColour, "#null") && !TextUtils.equals(feedFade, "#null")) {
			borderOne.setBackgroundColor(Color.parseColor(feedColour));
			borderTwo.setBackgroundColor(Color.parseColor(feedFade));
		} else {
			borderOne.setBackgroundColor(Color.GRAY);
			borderTwo.setBackgroundColor(Color.LTGRAY);
		}

		return v;
	}

}
