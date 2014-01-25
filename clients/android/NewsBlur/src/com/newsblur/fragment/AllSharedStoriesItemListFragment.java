package com.newsblur.fragment;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;
import android.support.v4.widget.CursorAdapter;
import android.support.v4.widget.SimpleCursorAdapter;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.activity.AllSharedStoriesReading;
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.SocialItemViewBinder;

public class AllSharedStoriesItemListFragment extends ItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener {

	public int currentState;
	private ContentResolver contentResolver;

	public static int ITEMLIST_LOADER = 0x01;
	private Cursor countCursor;
	private ListView itemList;
	private String[] groupFrom;
	private int[] groupTo;
    private StoryOrder storyOrder;

    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		currentState = getArguments().getInt("currentState");
        storyOrder = (StoryOrder)getArguments().getSerializable("storyOrder");
        defaultFeedView = (DefaultFeedView)getArguments().getSerializable("defaultFeedView");
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
		itemList.setEmptyView(v.findViewById(R.id.empty_view));

		contentResolver = getActivity().getContentResolver();

		groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORTDATE, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, DatabaseConstants.FEED_TITLE };
		groupTo = new int[] { R.id.row_item_title, R.id.row_item_author, R.id.row_item_title, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_feedtitle };
        // TODO: defer creation of the adapter until the loader's first callback so we don't leak this first cursor
        Cursor cursor = contentResolver.query(FeedProvider.ALL_SHARED_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
        adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_socialitem, cursor, groupFrom, groupTo, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);
        adapter.setViewBinder(new SocialItemViewBinder(getActivity()));
        itemList.setAdapter(adapter);

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);

		itemList.setOnScrollListener(this);
		itemList.setOnItemClickListener(this);

		return v;
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
	public void changeState(int state) {
		currentState = state;
        hasUpdated();
	}

	public static ItemListFragment newInstance(int currentState, StoryOrder storyOrder, DefaultFeedView defaultFeedView) {
		ItemListFragment everythingFragment = new AllSharedStoriesItemListFragment();
		Bundle arguments = new Bundle();
		arguments.putInt("currentState", currentState);
		arguments.putSerializable("storyOrder", storyOrder);
        arguments.putSerializable("defaultFeedView", defaultFeedView);
		everythingFragment.setArguments(arguments);

		return everythingFragment;
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
		Intent i = new Intent(getActivity(), AllSharedStoriesReading.class);
		i.putExtra(FeedReading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

	@Override
	public Loader<Cursor> onCreateLoader(int arg0, Bundle arg1) {
		return new CursorLoader(getActivity(), FeedProvider.ALL_SHARED_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
	}

	@Override
    public void setStoryOrder(StoryOrder storyOrder) {
        this.storyOrder = storyOrder;
    }

}
