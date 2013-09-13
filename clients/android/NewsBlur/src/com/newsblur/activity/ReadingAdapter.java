package com.newsblur.activity;

import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentStatePagerAdapter;
import android.util.Log;
import android.view.ViewGroup;

import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;

public abstract class ReadingAdapter extends FragmentStatePagerAdapter {

	protected Cursor stories;
	protected LoadingFragment loadingFragment;
	
	public ReadingAdapter(FragmentManager fm, Cursor stories) {
		super(fm);
		this.stories = stories;
	}
	
	@Override
	public abstract Fragment getItem(int position);
	
	@Override
	public int getCount() {
		if (stories != null && stories.getCount() > 0) {
			return stories.getCount();
		} else {
			return 1;
		}
	}

	public Story getStory(int position) {
		if (stories == null || position >= stories.getCount()) {
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
