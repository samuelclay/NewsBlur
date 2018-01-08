package com.newsblur.activity;

import android.database.Cursor;
import android.app.Fragment;
import android.app.FragmentManager;
import android.support.v13.app.FragmentStatePagerAdapter;
import android.util.SparseArray;
import android.view.ViewGroup;

import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;

import java.lang.ref.WeakReference;

public abstract class ReadingAdapter extends FragmentStatePagerAdapter {

	protected Cursor stories;
    protected String sourceUserId;
    private SparseArray<WeakReference<ReadingItemFragment>> cachedFragments;
	
	public ReadingAdapter(FragmentManager fm, String sourceUserId) {
		super(fm);
        this.cachedFragments = new SparseArray<WeakReference<ReadingItemFragment>>();
        this.sourceUserId = sourceUserId;
	}
	
	@Override
	public synchronized Fragment getItem(int position) {
		if (stories == null || stories.getCount() == 0 || position >= stories.getCount()) {
			return new LoadingFragment();
        } else {
            stories.moveToPosition(position);
            Story story = Story.fromCursor(stories);
            ReadingItemFragment frag = getReadingItemFragment(story);
            return frag;
        }
    }

    @Override
    public Object instantiateItem(ViewGroup container, int position) {
        Object o = super.instantiateItem(container, position);
        if (o instanceof ReadingItemFragment) {
            cachedFragments.put(position, new WeakReference((ReadingItemFragment) o));
        }
        return o;
    }

    @Override
    public void destroyItem(ViewGroup container, int position, Object object) {
        cachedFragments.remove(position);
        try {
            super.destroyItem(container, position, object);
        } catch (IllegalStateException ise) {
            // it appears that sometimes the pager impatiently deletes stale fragments befre
            // even calling it's own destroyItem method.  we're just passing up the stack
            // after evicting our cache, so don't expose this internal bug from our call stack
            com.newsblur.util.Log.w(this, "ViewPager adapter rejected own destruction call.");
        }
    }

    public synchronized void swapCursor(Cursor cursor) {
        this.stories = cursor;
        if (cursor != null) {
            notifyDataSetChanged();
        }
    }
        
	protected abstract ReadingItemFragment getReadingItemFragment(Story story);
	
	@Override
	public synchronized int getCount() {
		if (stories != null && stories.getCount() > 0) {
			return stories.getCount();
		} else {
			return 1;
		}
	}

	public synchronized Story getStory(int position) {
		if (stories == null || stories.isClosed() || stories.getColumnCount() == 0 || position >= stories.getCount() || position < 0) {
			return null;
		} else {
			stories.moveToPosition(position);
			Story story = Story.fromCursor(stories);
            return story;
		}
	}

    public synchronized int getPosition(Story story) {
        if (stories == null) return -1;
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

    public String getSourceUserId() {
        return sourceUserId;
    }

    public synchronized ReadingItemFragment getExistingItem(int pos) {
        WeakReference<ReadingItemFragment> frag = cachedFragments.get(pos);
        if (frag == null) return null;
        return frag.get();
    }

    @Override
    public synchronized void notifyDataSetChanged() {
        super.notifyDataSetChanged();

        // go one step further than the default pageradapter and also refresh the
        // story object inside each fragment we have active
        for (int i=0; i<stories.getCount(); i++) {
            WeakReference<ReadingItemFragment> frag = cachedFragments.get(i);
            if (frag == null) continue;
            ReadingItemFragment rif = frag.get();
            if (rif == null) continue;
            rif.offerStoryUpdate(getStory(i));
            rif.handleUpdate(NbActivity.UPDATE_STORY);
        }
    }
}
