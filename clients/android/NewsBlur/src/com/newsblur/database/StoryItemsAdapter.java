package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.widget.SimpleCursorAdapter;

import java.util.List;

import com.newsblur.domain.Story;

public abstract class StoryItemsAdapter extends SimpleCursorAdapter {

	public StoryItemsAdapter(Context context, int layout, Cursor c, String[] from, int[] to) {
        // don't set *any* flags, we use auto-refreshing Loaders or plain Loaders and an explict load after syncs
		super(context, layout, c, from, to, 0);
    }

    public abstract Story getStory(int position);

}
