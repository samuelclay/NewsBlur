package com.newsblur.fragment;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;
import android.support.v4.widget.CursorAdapter;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.activity.AllStoriesReading;
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.database.StoryItemsAdapter;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.SocialItemViewBinder;

public class AllStoriesItemListFragment extends StoryItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener {

	public int currentState;
	private ContentResolver contentResolver;
	
    private StoryOrder storyOrder;

	public static int ITEMLIST_LOADER = 0x01;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		currentState = getArguments().getInt("currentState");
		storyOrder = (StoryOrder)getArguments().getSerializable("storyOrder");
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);

		itemList.setEmptyView(v.findViewById(R.id.empty_view));

		Cursor cursor = getActivity().getContentResolver().query(FeedProvider.ALL_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
		String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORTDATE, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, DatabaseConstants.FEED_TITLE };
		int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_author, R.id.row_item_title, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_feedtitle };

		adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_socialitem, cursor, groupFrom, groupTo, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);

		itemList.setOnScrollListener(this);

		adapter.setViewBinder(new SocialItemViewBinder(getActivity()));
		itemList.setAdapter(adapter);
		itemList.setOnItemClickListener(this);
		itemList.setOnCreateContextMenuListener(this);

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
	
	public static ItemListFragment newInstance(int currentState, StoryOrder storyOrder) {
		ItemListFragment everythingFragment = new AllStoriesItemListFragment();
		Bundle arguments = new Bundle();
		arguments.putInt("currentState", currentState);
		arguments.putSerializable("storyOrder", storyOrder);
		everythingFragment.setArguments(arguments);

		return everythingFragment;
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
		Intent i = new Intent(getActivity(), AllStoriesReading.class);
		i.putExtra(FeedReading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
		startActivity(i);
	}

	@Override
	public Loader<Cursor> onCreateLoader(int arg0, Bundle arg1) {
		return new CursorLoader(getActivity(), FeedProvider.ALL_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
	}

	@Override
    public void setStoryOrder(StoryOrder storyOrder) {
        this.storyOrder = storyOrder;
    }

}
