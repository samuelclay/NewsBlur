package com.newsblur.activity;

import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentStatePagerAdapter;

import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.util.DefaultFeedView;

public abstract class ReadingAdapter extends FragmentStatePagerAdapter {

	protected Cursor stories;
    protected DefaultFeedView defaultFeedView;
	
	public ReadingAdapter(FragmentManager fm, DefaultFeedView defaultFeedView) {
		super(fm);
        this.defaultFeedView = defaultFeedView;
	}
	
	@Override
	public synchronized Fragment getItem(int position) {
		if (stories == null || stories.getCount() == 0 || position >= stories.getCount()) {
			return new LoadingFragment();
        } else {
            return getReadingItemFragment(position);
        }
    }

    public synchronized void swapCursor(Cursor cursor) {
        this.stories = cursor;
    }
        
	protected abstract Fragment getReadingItemFragment(int position);
	
	@Override
	public synchronized int getCount() {
		if (stories != null && stories.getCount() > 0) {
			return stories.getCount();
		} else {
			return 1;
		}
	}

	public synchronized Story getStory(int position) {
		if (stories == null || stories.getColumnCount() == 0 || position >= stories.getCount() || position < 0) {
			return null;
		} else {
			stories.moveToPosition(position);
			return Story.fromCursor(stories);
		}
	}

    public synchronized int getPosition(Story story) {
        int pos = 0;
        while (pos < stories.getCount()) {
			stories.moveToPosition(pos);
            if (Story.fromCursor(stories).equals(story)) {
                return pos;
            }
            pos++;
        }
        return -1;
    }
	
	@Override
	public synchronized int getItemPosition(Object object) {
		if (object instanceof LoadingFragment) {
			return POSITION_NONE;
		} else {
			return POSITION_UNCHANGED;
		}
	}

}
