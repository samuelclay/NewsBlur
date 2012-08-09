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
		View border = v.findViewById(R.id.row_item_favicon_borderbar);

		cursor.moveToPosition(position);
		
		GradientDrawable gradient;
		String feedColour = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOUR));
		String feedFade = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));

		if (!TextUtils.equals(feedColour, "#null") && !TextUtils.equals(feedFade, "#null")) {
			gradient = new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, new int[] { Color.parseColor(feedColour), Color.parseColor(feedFade)});
		} else {
			gradient = new GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, new int[] { Color.DKGRAY, Color.LTGRAY });
		}
		Drawable[] layers = new Drawable[2];
		layers[0] = gradient;
		layers[1] = context.getResources().getDrawable(R.drawable.shiny_plastic);
		border.setBackgroundDrawable(new LayerDrawable(layers));

		return v;
	}

}
