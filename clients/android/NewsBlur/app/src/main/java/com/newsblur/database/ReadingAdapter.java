package com.newsblur.database;

import android.database.Cursor;
import android.os.Bundle;
import android.os.Parcelable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import androidx.viewpager.widget.PagerAdapter;
import android.view.View;
import android.view.ViewGroup;

import com.newsblur.activity.Reading;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.service.NBSyncReceiver;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * An adapter to display stories in a ViewPager. Loosely based upon FragmentStatePagerAdapter, but
 * with enhancements to correctly handle item insertion / removal and to pass invalidation down
 * to child fragments during updates.
 */
public class ReadingAdapter extends PagerAdapter {

    private String sourceUserId;
    private boolean showFeedMetadata;
    private Reading activity;
    private FragmentManager fm;
    private FragmentTransaction curTransaction = null;
    private Fragment lastActiveFragment = null;
    private HashMap<String,ReadingItemFragment> fragments;
    private HashMap<String,Fragment.SavedState> states;

    // the cursor from which we pull story objects. should not be used except by the thaw worker
    private Cursor mostRecentCursor;
    // the live list of stories being used by the adapter
    private List<Story> stories = new ArrayList<Story>(0);

    // classifiers for each feed seen in the story list
    private Map<String,Classifier> classifiers = new HashMap<String,Classifier>(0);

    private final ExecutorService executorService;
    private final BlurDatabaseHelper dbHelper;

	public ReadingAdapter(FragmentManager fm, String sourceUserId, boolean showFeedMetadata, Reading activity, BlurDatabaseHelper dbHelper) {
        this.sourceUserId = sourceUserId;
        this.showFeedMetadata = showFeedMetadata;
		this.fm = fm;
        this.activity = activity;
        this.dbHelper = dbHelper;

        this.fragments = new HashMap<String,ReadingItemFragment>();
        this.states = new HashMap<String,Fragment.SavedState>();

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
                // keep track of which feeds are in this story set so we can also fetch Classifiers
                Set<String> feedIdsSeen = new HashSet<String>();
                c.moveToPosition(-1);
                while (c.moveToNext()) {
                    if (c.isClosed()) return;
                    Story s = Story.fromCursor(c);
                    s.bindExternValues(c);
                    newStories.add(s);
                    feedIdsSeen.add(s.feedId);
                }
                for (String feedId : feedIdsSeen) {
                    classifiers.put(feedId, dbHelper.getClassifierForFeed(feedId));
                }
            }
        } catch (Exception e) {
            // because we use interruptable loaders that auto-close cursors, it is expected
            // that cursors will sometimes go bad. this is a useful signal to stop the thaw
            // thread and let it start on a fresh cursor.
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
        return ReadingItemFragment.newInstance(story, 
                                               story.extern_feedTitle, 
                                               story.extern_feedColor, 
                                               story.extern_feedFade, 
                                               story.extern_faviconBorderColor, 
                                               story.extern_faviconTextColor, 
                                               story.extern_faviconUrl, 
                                               classifiers.get(story.feedId), 
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
                Fragment.SavedState oldState = states.get(story.storyHash);
                if (oldState != null) fragment.setInitialSavedState(oldState);
                fragments.put(story.storyHash, rif);
            } else {
                // iff there was a real fragment for this story already, it will have been added and ready
                return fragment;
            }
        }
        fragment.setMenuVisibility(false);
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
            if (rif.isAdded()) {
                states.put(rif.story.storyHash, fm.saveFragmentInstanceState(rif));
            }
            fragments.remove(rif.story.storyHash);
        }
    }

    @Override
    public void setPrimaryItem(ViewGroup container, int position, Object object) {
        Fragment fragment = (Fragment) object;
        if (fragment != lastActiveFragment) {
            if (lastActiveFragment != null) {
                lastActiveFragment.setMenuVisibility(false);
            }
            if (fragment != null) {
                fragment.setMenuVisibility(true);
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
                rif.handleUpdate(NBSyncReceiver.UPDATE_STORY);
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

    @Override
    public Parcelable saveState() {
        // collect state from any active fragments alongside already-frozen ones
        for (Map.Entry<String,ReadingItemFragment> entry : fragments.entrySet()) {
            Fragment f = entry.getValue();
            if (f.isAdded()) {
                states.put(entry.getKey(), fm.saveFragmentInstanceState(f));
            }
        }
        Bundle state = new Bundle();
        for (Map.Entry<String,Fragment.SavedState> entry : states.entrySet()) {
            state.putParcelable("ss-" + entry.getKey(), entry.getValue());
        }
        return state;
    }

    @Override
    public void restoreState(Parcelable state, ClassLoader loader) {
        // most FragmentManager impls. will re-create added fragments even if they
        // are not set to retaininstance. we want to only save state, not objects,
        // so before we start restoration, clear out any stale instances.  without
        // this, the pager will leak fragments on rotation or context switch.
        for (Fragment fragment : fm.getFragments()) {
            if (fragment instanceof ReadingItemFragment) {
                fm.beginTransaction().remove(fragment).commit();
            }
        }
        Bundle bundle = (Bundle)state;
        bundle.setClassLoader(loader);
        fragments.clear();
        states.clear();
        for (String key : bundle.keySet()) {
            if (key.startsWith("ss-")) {
                String storyHash = key.substring(3);
                Parcelable fragState = bundle.getParcelable(key);
                states.put(storyHash, (Fragment.SavedState) fragState);
            }
        }
    }

}
