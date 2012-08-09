package com.newsblur.database;

import android.content.Context;
import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentStatePagerAdapter;
import android.util.Log;
import android.view.ViewGroup;

import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;

public class FeedReadingAdapter extends FragmentStatePagerAdapter {

	private Cursor cursor;
	private String TAG = "ReadingAdapter";
	private LoadingFragment loadingFragment; 

	public FeedReadingAdapter(final FragmentManager fragmentManager, final Context context, final Cursor cursor) {
		super(fragmentManager);
		this.cursor = cursor;
	}
	
	
	@Override
	public Fragment getItem(int position) {
		if (cursor == null || cursor.getCount() == 0) {
			loadingFragment = new LoadingFragment();
			return loadingFragment;
		} else {
			cursor.moveToPosition(position);
			return ReadingItemFragment.newInstance(Story.fromCursor(cursor));
		}
	}
	
	@Override
	public void setPrimaryItem(ViewGroup container, int position, Object object) {
		super.setPrimaryItem(container, position, object);
	}

	@Override
	public int getCount() {
		if (cursor != null && cursor.getCount() > 0) {
			return cursor.getCount();
		} else {
			Log.d(TAG , "No cursor - use loading view.");
			return 1;
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
	public int getItemPosition(Object object) {
		if (object instanceof LoadingFragment) {
			return POSITION_NONE;
		} else {
			return POSITION_UNCHANGED;
		}
	}


}
