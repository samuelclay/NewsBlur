package com.newsblur.database;

import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.support.v4.view.PagerAdapter;
import android.view.View;
import android.view.ViewGroup;

import com.newsblur.activity.NbActivity;
import com.newsblur.activity.Reading;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.util.FeedUtils;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class ReadingAdapter extends PagerAdapter {

    private String sourceUserId;
    private boolean showFeedMetadata;
    private Reading activity;
    private FragmentManager fm;
    private FragmentTransaction curTransaction = null;
    private Fragment lastActiveFragment = null;
    private HashMap<String,ReadingItemFragment> fragments;

    // the cursor from which we pull story objects. should not be used except by the thaw worker
    private Cursor mostRecentCursor;
    // the live list of stories being used by the adapter
    private List<Story> stories = new ArrayList<Story>(0);

    private final ExecutorService executorService;

	public ReadingAdapter(FragmentManager fm, String sourceUserId, boolean showFeedMetadata, Reading activity) {
        this.sourceUserId = sourceUserId;
        this.showFeedMetadata = showFeedMetadata;
		this.fm = fm;
        this.activity = activity;

        this.fragments = new HashMap<String,ReadingItemFragment>();

        executorService = Executors.newFixedThreadPool(1);
	}

    public void swapCursor(final Cursor c, final View v) {
        // cache the identity of the most recent cursor so async batches can check to
        // see if they are stale
        mostRecentCursor = c;
        // process the cursor into objects and update the View async
        Runnable r = new Runnable() {
            @Override
            public void run() {
                thaw(c, v);
            }
        };
        executorService.submit(r);
    }

    /**
     * Attempt to thaw a new set of stories from the cursor most recently
     * seen when the that cycle started.
     */
    private void thaw(final Cursor c, View v) {
        if (c != mostRecentCursor) return;

        // thawed stories
        final List<Story> newStories;
        // attempt to thaw as gracefully as possible despite the fact that the loader
        // framework could close our cursor at any moment.  if this happens, it is fine,
        // as a new one will be provided and another cycle will start.  just return.
        try {
            if (c == null) {
                newStories = new ArrayList<Story>(0);
            } else {
                if (c.isClosed()) return;
                newStories = new ArrayList<Story>(c.getCount());
                c.moveToPosition(-1);
                while (c.moveToNext()) {
                    if (c.isClosed()) return;
                    Story s = Story.fromCursor(c);
                    s.bindExternValues(c);
                    newStories.add(s);
                }
            }
        } catch (Exception e) {
            com.newsblur.util.Log.e(this, "error thawing story list: " + e.getMessage(), e);
            return;
        }

        if (c != mostRecentCursor) return;

        v.post(new Runnable() {
            @Override
            public void run() {
                if (c != mostRecentCursor) return;
                stories = newStories;
                notifyDataSetChanged();
                activity.pagerUpdated();
            }
        });
    }

    public Story getStory(int position) {
        if (position >= stories.size() || position < 0) {
            return null;
        } else {
            return stories.get(position);
        }
    }

	@Override
	public int getCount() {
        return stories.size();
	}
	
	private ReadingItemFragment createFragment(Story story) {
        // TODO: classifiers should be pre-fetched by loaders?
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

    @Override
    public Object instantiateItem(ViewGroup container, int position) {
        Story story = getStory(position);
        Fragment fragment = null;
		if (story == null) {
			fragment = new LoadingFragment();
        } else {
            fragment = fragments.get(story.storyHash);
            if (fragment == null) {
                ReadingItemFragment rif = createFragment(story);
                fragment = rif;
                // TODO: restore state?
                fragments.put(story.storyHash, rif);
            } else {
                // iff there was a real fragment for this story already, it will have been added and ready
                return fragment;
            }
        }
        fragment.setMenuVisibility(false);
        fragment.setUserVisibleHint(false);
        if (curTransaction == null) {
            curTransaction = fm.beginTransaction();
        }
        curTransaction.add(container.getId(), fragment);
        return fragment;
    }

    @Override
    public void destroyItem(ViewGroup container, int position, Object object) {
        Fragment fragment = (Fragment) object;
        if (curTransaction == null) {
            curTransaction = fm.beginTransaction();
        }
        curTransaction.remove(fragment);
        if (fragment instanceof ReadingItemFragment) {
            ReadingItemFragment rif = (ReadingItemFragment) fragment;
            // TODO: save state?
            fragments.remove(rif.story.storyHash);
        }
    }

    @Override
    public void setPrimaryItem(ViewGroup container, int position, Object object) {
        Fragment fragment = (Fragment) object;
        if (fragment != lastActiveFragment) {
            if (lastActiveFragment != null) {
                lastActiveFragment.setMenuVisibility(false);
                lastActiveFragment.setUserVisibleHint(false);
            }
            if (fragment != null) {
                fragment.setMenuVisibility(true);
                fragment.setUserVisibleHint(true);
            }
            lastActiveFragment = fragment;
        }
    }

    @Override
    public void finishUpdate(ViewGroup container) {
        if (curTransaction != null) {
            curTransaction.commitNowAllowingStateLoss();
            curTransaction = null;
        }
    }

    @Override
    public boolean isViewFromObject(View view, Object object) {
        return ((Fragment)object).getView() == view;
    }

    /**
     * get the number of stories we very likely have, even if they haven't
     * been thawed yet, for callers that absolutely must know the size
     * of our dataset (such as for calculating when to fetch more stories)
     */
    public int getRawStoryCount() {
        if (mostRecentCursor == null) return 0;
        if (mostRecentCursor.isClosed()) return 0;
        int count = 0;
        try {
            count = mostRecentCursor.getCount();
        } catch (Exception e) {
            // rather than worry about sync locking for cursor changes, just fail. a
            // closing cursor may as well not be loaded.
        }
        return count;
    }

    public int getPosition(Story story) {
        int pos = 0;
        while (pos < stories.size()) {
            if (stories.get(pos).equals(story)) {
                return pos;
            }
            pos++;
        }
        return -1;
    }
	
	@Override
	public int getItemPosition(Object object) {
		if (object instanceof ReadingItemFragment) {
            ReadingItemFragment rif = (ReadingItemFragment) object;
            int pos = findHash(rif.story.storyHash);
            if (pos >=0) return pos;
		}
        return POSITION_NONE;
	}

    public ReadingItemFragment getExistingItem(int pos) {
        Story story = getStory(pos);
        if (story == null) return null;
        return fragments.get(story.storyHash);
    }

    @Override
    public void notifyDataSetChanged() {
        super.notifyDataSetChanged();

        // go one step further than the default pageradapter and also refresh the
        // story object inside each fragment we have active
        for (Story s : stories) {
            ReadingItemFragment rif = fragments.get(s.storyHash);
            if (rif != null ) {
                rif.offerStoryUpdate(s);
                rif.handleUpdate(NbActivity.UPDATE_STORY);
            }
        }
    }

    public int findFirstUnread() {
        int pos = 0;
        while (pos < stories.size()) {
            if (! stories.get(pos).read) {
                return pos;
            }
            pos++;
        }
        return -1;
    }

    public int findHash(String storyHash) {
        int pos = 0;
        while (pos < stories.size()) {
            if (stories.get(pos).storyHash.equals(storyHash)) {
                return pos;
            }
            pos++;
        }
        return -1;
    }
}
