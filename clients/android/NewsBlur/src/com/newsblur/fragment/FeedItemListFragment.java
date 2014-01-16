package com.newsblur.fragment;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;
import android.support.v4.widget.CursorAdapter;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedItemsAdapter;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Feed;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.FeedItemViewBinder;

public class FeedItemListFragment extends StoryItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener {

	private String feedId;
	private int currentState;

	public static int ITEMLIST_LOADER = 0x01;
	
    private StoryOrder storyOrder;

    public static FeedItemListFragment newInstance(String feedId, int currentState, StoryOrder storyOrder, DefaultFeedView defaultFeedView) {
		FeedItemListFragment feedItemFragment = new FeedItemListFragment();

		Bundle args = new Bundle();
		args.putInt("currentState", currentState);
		args.putString("feedId", feedId);
		args.putSerializable("storyOrder", storyOrder);
        args.putSerializable("defaultFeedView", defaultFeedView);
		feedItemFragment.setArguments(args);

		return feedItemFragment;
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		currentState = getArguments().getInt("currentState");
		feedId = getArguments().getString("feedId");
		storyOrder = (StoryOrder)getArguments().getSerializable("storyOrder");
        defaultFeedView = (DefaultFeedView)getArguments().getSerializable("defaultFeedView");
	}

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_itemlist, null);
        ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);

        itemList.setEmptyView(v.findViewById(R.id.empty_view));

        ContentResolver contentResolver = getActivity().getContentResolver();
        Uri storiesUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
        Cursor storiesCursor = contentResolver.query(storiesUri, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
        Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
        Cursor feedCursor = contentResolver.query(feedUri, null, null, null, null);

        if (feedCursor.getCount() < 1) {
            // This shouldn't happen, but crash reports indicate that it does (very rarely).
            // If we are told to create an item list for a feed, but then can't find that feed ID in the DB,
            // something is very wrong, and we won't be able to recover, so just force the user back to the
            // feed list until we have a better understanding of how to prevent this.
            Log.w(this.getClass().getName(), "Feed not found in DB, can't create item list.");
            getActivity().finish();
            return v;
        }

        feedCursor.moveToFirst();
        Feed feed = Feed.fromCursor(feedCursor);

        String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_READ, DatabaseConstants.STORY_SHORTDATE, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS };
        int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_author, R.id.row_item_title, R.id.row_item_date, R.id.row_item_sidebar };

        // create the adapter before starting the loader, since the callback updates the adapter
        adapter = new FeedItemsAdapter(getActivity(), feed, R.layout.row_item, storiesCursor, groupFrom, groupTo, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);

        getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);

        itemList.setOnScrollListener(this);

        adapter.setViewBinder(new FeedItemViewBinder(getActivity()));
        itemList.setAdapter(adapter);
        itemList.setOnItemClickListener(this);
        itemList.setOnCreateContextMenuListener(this);
        
        return v;
    }

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
		Uri uri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
		CursorLoader cursorLoader = new CursorLoader(getActivity(), uri, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
		return cursorLoader;
	}

	public void hasUpdated() {
        if (isAdded()) {
		    getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
        }
		requestedPage = false;
	}

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		adapter.notifyDataSetInvalidated();
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
		Intent i = new Intent(getActivity(), FeedReading.class);
		i.putExtra(Reading.EXTRA_FEED, feedId);
		i.putExtra(FeedReading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

	public void changeState(int state) {
		currentState = state;
		hasUpdated();
	}

    @Override
    public void setStoryOrder(StoryOrder storyOrder) {
        this.storyOrder = storyOrder;
    }

}
