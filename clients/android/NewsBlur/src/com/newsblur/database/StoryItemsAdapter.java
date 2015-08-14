package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.widget.SimpleCursorAdapter;

import java.util.List;

import com.newsblur.domain.Story;

public class StoryItemsAdapter extends SimpleCursorAdapter {

	protected Cursor cursor;

    // should be subclassed to handle bindView(), not created directly
	protected StoryItemsAdapter(Context context, int layout, Cursor c, String[] from, int[] to) {
        // don't set *any* flags, we use auto-refreshing Loaders or plain Loaders and an explict load after syncs
		super(context, layout, c, from, to, 0);
        cursor = c;
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

	public Story getStory(int position) {
        cursor.moveToPosition(position);
        return Story.fromCursor(cursor);
    }

}
