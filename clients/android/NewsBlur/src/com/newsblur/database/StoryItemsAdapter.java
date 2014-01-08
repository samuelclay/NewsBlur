package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.support.v4.widget.SimpleCursorAdapter;

import java.util.List;

import com.newsblur.domain.Story;

public abstract class StoryItemsAdapter extends SimpleCursorAdapter {

	public StoryItemsAdapter(Context context, int layout, Cursor c, String[] from, int[] to, int flags) {
		super(context, layout, c, from, to, flags);
    }

    public abstract Story getStory(int position);

    public abstract List<Story> getPreviousStories(int position);

}
