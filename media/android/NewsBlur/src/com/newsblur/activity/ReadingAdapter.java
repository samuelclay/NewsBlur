package com.newsblur.activity;

import android.content.Context;
import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentStatePagerAdapter;
import android.util.Log;
import android.view.ViewGroup;

import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;

public abstract class ReadingAdapter extends FragmentStatePagerAdapter {


	protected Cursor stories;
	private String TAG = "ReadingAdapter";
	protected LoadingFragment loadingFragment;
	
	public ReadingAdapter(FragmentManager fm, Cursor stories) {
		super(fm);
		this.stories = stories;
	}
	
	@Override
	public abstract Fragment getItem(int position);
	
	@Override
	public void setPrimaryItem(ViewGroup container, int position, Object object) {
		super.setPrimaryItem(container, position, object);
	}

	@Override
	public int getCount() {
		if (stories != null && stories.getCount() > 0) {
			return stories.getCount();
		} else {
			Log.d(TAG , "No cursor - use loading view.");
			return 1;
		}
	}

	public Story getStory(int position) {
		if (stories == null || position > stories.getCount()) {
			return null;
		} else {
			stories.moveToPosition(position);
			return Story.fromCursor(stories);
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
