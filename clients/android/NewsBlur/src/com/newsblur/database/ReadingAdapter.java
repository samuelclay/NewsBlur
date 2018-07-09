package com.newsblur.database;

import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentStatePagerAdapter;
import android.util.SparseArray;
import android.view.ViewGroup;

import com.newsblur.activity.NbActivity;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.util.FeedUtils;

import java.lang.ref.WeakReference;

public class ReadingAdapter extends FragmentStatePagerAdapter {

	private Cursor stories;
    private String sourceUserId;
    private boolean showFeedMetadata;
    private SparseArray<WeakReference<ReadingItemFragment>> cachedFragments;
	
	public ReadingAdapter(FragmentManager fm, String sourceUserId, boolean showFeedMetadata) {
		super(fm);
        this.cachedFragments = new SparseArray<WeakReference<ReadingItemFragment>>();
        this.sourceUserId = sourceUserId;
        this.showFeedMetadata = showFeedMetadata;
	}
	
	@Override
	public synchronized Fragment getItem(int position) {
		if (stories == null || stories.getCount() == 0 || position >= stories.getCount()) {
			return new LoadingFragment();
        } else {
            stories.moveToPosition(position);
            Story story = Story.fromCursor(stories);
            story.bindExternValues(stories);

            // TODO: does the pager generate new fragments in the UI thread? If so, classifiers should
            // be loaded async by the fragment itself
            Classifier classifier = FeedUtils.dbHelper.getClassifierForFeed(story.feedId);

            return ReadingItemFragment.newInstance(story, 
                                                   story.extern_feedTitle, 
                                                   story.extern_feedColor, 
                                                   story.extern_feedFade, 
                                                   story.extern_faviconBorderColor, 
                                                   story.extern_faviconTextColor, 
                                                   story.extern_faviconUrl, 
                                                   classifier, 
                                                   showFeedMetadata, 
                                                   sourceUserId);
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
        notifyDataSetChanged();
    }
        
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
        if (stories.isClosed()) return -1;
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
        if (stories == null) return;
        for (int i=0; i<stories.getCount(); i++) {
            WeakReference<ReadingItemFragment> frag = cachedFragments.get(i);
            if (frag == null) continue;
            ReadingItemFragment rif = frag.get();
            if (rif == null) continue;
            rif.offerStoryUpdate(getStory(i));
            rif.handleUpdate(NbActivity.UPDATE_STORY);
        }
    }

    public synchronized int findFirstUnread() {
        stories.moveToPosition(-1);
        while (stories.moveToNext()) {
            Story story = Story.fromCursor(stories);
            if (!story.read) return stories.getPosition();
        }
        return -1;
    }

    public synchronized int findHash(String storyHash) {
        stories.moveToPosition(-1);
        while (stories.moveToNext()) {
            Story story = Story.fromCursor(stories);
            if (story.storyHash.equals(storyHash)) return stories.getPosition();
        }
        return -1;
    }
}
