package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.support.v4.widget.SimpleCursorAdapter;
import android.text.TextUtils;
import android.view.View;
import android.view.ViewGroup;

import com.newsblur.R;

public class SocialFeedItemsAdapter extends SimpleCursorAdapter {

	private Cursor cursor;
	private Context context;

	public SocialFeedItemsAdapter(Context context, int layout, Cursor c, String[] from, int[] to, int flags) {
		super(context, layout, c, from, to, flags);
		this.context = context;
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
		String feedColour = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOUR));
		String feedFade = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));

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
