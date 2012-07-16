package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentStatePagerAdapter;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;
import android.util.Log;

import com.newsblur.domain.Story;
import com.newsblur.fragment.ReadingItemFragment;

public class ReadingAdapter extends FragmentStatePagerAdapter implements LoaderManager.LoaderCallbacks<Cursor> {
	
	private Context context;
	private Cursor cursor;
	private Uri feedUri;
	private String TAG = "ReadingAdapter"; 
	
	public ReadingAdapter(final FragmentManager fragmentManager, final Context context, final String feedId) {
		super(fragmentManager);
		this.context = context;
		feedUri = FeedProvider.STORIES_URI.buildUpon().appendPath(feedId).build();
	}
	
	@Override
	public Fragment getItem(int position) {
		if (cursor == null) {
			return null;
		} else {
			cursor.moveToPosition(position);
			return new ReadingItemFragment(Story.fromCursor(cursor));
		}
	}

	@Override
	public int getCount() {
		if (cursor != null) {
			return cursor.getCount();
		} else {
			Log.d(TAG , "No cursor");
			return 0;
		}
	}
	
	public Story getStory(int position) {
		if (cursor == null || position > cursor.getCount()) {
			return null;
		} else {
			cursor.moveToPosition(position);
			return Story.fromCursor(cursor);
		}
	}

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
		CursorLoader cursorLoader = new CursorLoader(context, feedUri, null, null, null, null);
	    return cursorLoader;
	}

	@Override
	public void onLoadFinished(Loader<Cursor> arg0, Cursor cursor) {
		this.cursor = cursor;
		notifyDataSetChanged();
	}

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		notifyDataSetChanged();
	}
	
	

}
