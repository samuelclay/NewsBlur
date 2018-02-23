package com.newsblur.fragment;

import android.app.LoaderManager;
import android.content.Loader;
import android.database.Cursor;
import android.os.Bundle;
import android.util.Log;

import com.newsblur.activity.ItemsList;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;

public abstract class ItemSetFragment extends NbFragment implements LoaderManager.LoaderCallbacks<Cursor> {

	public static int ITEMLIST_LOADER = 0x01;

    protected ItemsList activity;
    protected boolean cursorSeenYet = false;
    private boolean stopLoading = false;
    
    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
        activity = (ItemsList) getActivity();

        if (getFeedSet() == null) {
            com.newsblur.util.Log.w(this.getClass().getName(), "item list started without FeedSet.");
            activity.finish();
            return;
        }

        // warm up the sync service as soon as possible since it will init the story session DB
        triggerRefresh(1, null);
    }

    @Override
    public void onStart() {
        super.onStart();
        stopLoading = false;
        getLoaderManager().initLoader(ITEMLIST_LOADER, null, this);
    }

    @Override
    public void onPause() {
        // a pause/resume cycle will depopulate and repopulate the list and trigger bad scroll
        // readings and cause zero-index refreshes, wasting massive cycles. hold the refresh logic
        // until the loaders reset
        cursorSeenYet = false;
        super.onPause();
    }

    @Override
    public void onResume() {
        if (!isAdapterValid()) {
            Log.e(this.getClass().getName(), "stale fragment loaded, falling back.");
            getActivity().finish();
        }
        super.onResume();
    }

    /** 
     * Sanity check the adapter, iff it exists. If false, the activity will finish.
     */
    protected abstract boolean isAdapterValid();

    protected void triggerRefresh(int desiredStoryCount, Integer totalSeen) {
        if (getFeedSet().isMuted()) return;

        // ask the sync service for as many stories as we want
        boolean gotSome = NBSyncService.requestMoreForFeed(getFeedSet(), desiredStoryCount, totalSeen);
        // if the service thinks it can get more, or if we haven't even seen a cursor yet, start the service
        if (gotSome || (totalSeen == null)) triggerSync();
    }

    /**
     * Signal that all futher cursor loads should be ignored
     */
    public void stopLoader() {
        stopLoading = true;
    }

    /**
     * Indicate that the DB was cleared.
     */
    public void resetEmptyState() {
        setShowNone(true);
        cursorSeenYet = false;
    }

    public abstract void setLoading(boolean isLoading);

    private void updateLoadingMessage() {
        boolean isMuted = getFeedSet().isMuted();
        boolean isLoading = NBSyncService.isFeedSetSyncing(getFeedSet(), activity);
        updateLoadingMessage(isMuted, isLoading);
    }

    protected abstract void updateLoadingMessage(boolean isMuted, boolean isLoading);

    public abstract void scrollToTop();

    protected FeedSet getFeedSet() {
        return activity.getFeedSet();
    }

	public void hasUpdated() {
        if (isAdded() && !getFeedSet().isMuted()) {
		    getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
        }
	}

	@Override
	public Loader<Cursor> onCreateLoader(int arg0, Bundle arg1) {
        FeedSet fs = getFeedSet();
        if (fs == null) {
            Log.e(this.getClass().getName(), "can't create fragment, no feedset ready");
            // this is probably happening in a finalisation cycle or during a crash, pop the activity stack
            try {
                getActivity().finish();
            } catch (Exception e) {
                ;
            }
            return null;
        } else if (fs.isMuted()) {
            updateLoadingMessage();
            return null;
        } else {
            return FeedUtils.dbHelper.getActiveStoriesLoader(getFeedSet());
        }
    }

    @Override
	public synchronized void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if (stopLoading) return;
		if (cursor != null) {
            createAdapter(cursor);
            if (! NBSyncService.isFeedSetReady(getFeedSet())) {
                // the DB hasn't caught up yet from the last story list; don't display stale stories.
                com.newsblur.util.Log.i(this.getClass().getName(), "stale load");
                setShowNone(true);
                setLoading(true);
                triggerRefresh(1, null);
            } else {
                cursorSeenYet = true;
                com.newsblur.util.Log.d(this.getClass().getName(), "loaded cursor with count: " + cursor.getCount());
                if (cursor.getCount() < 1) {
                    triggerRefresh(1, 0);
                }
                setShowNone(false);
            }
            updateAdapter(cursor);
		}
        updateLoadingMessage();
	}

    /** 
     * Create and set the adapter iff it is still null.
     */
    protected abstract void createAdapter(Cursor cursor);

    protected abstract void updateAdapter(Cursor cursor);

    protected abstract void setShowNone(boolean showNone);

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
        ;
	}

    public abstract void setTextSize(Float size);

}
