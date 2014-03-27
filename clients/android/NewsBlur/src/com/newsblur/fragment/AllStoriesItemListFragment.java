package com.newsblur.fragment;

import java.util.ArrayList;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.app.LoaderManager;
import android.content.CursorLoader;
import android.content.Loader;
import android.widget.CursorAdapter;
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
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.SocialItemViewBinder;

public class AllStoriesItemListFragment extends ItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener {

    private String[] feedIds;
	private int currentState;
	private ContentResolver contentResolver;
	
    private StoryOrder storyOrder;

	public static int ITEMLIST_LOADER = 0x01;

    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		currentState = getArguments().getInt("currentState");
		storyOrder = (StoryOrder)getArguments().getSerializable("storyOrder");
        defaultFeedView = (DefaultFeedView)getArguments().getSerializable("defaultFeedView");
		ArrayList<String> feedIdArrayList = getArguments().getStringArrayList("feedIds");
		feedIds = new String[feedIdArrayList.size()];
		feedIdArrayList.toArray(feedIds);
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        setupBezelSwipeDetector(itemList);

		itemList.setEmptyView(v.findViewById(R.id.empty_view));

		Cursor cursor = getActivity().getContentResolver().query(FeedProvider.ALL_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
		getActivity().startManagingCursor(cursor);
		String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, DatabaseConstants.FEED_TITLE };
		int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_author, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_feedtitle };

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
	
	public static ItemListFragment newInstance(ArrayList<String> feedIds, int currentState, StoryOrder storyOrder, DefaultFeedView defaultFeedView) {
		ItemListFragment everythingFragment = new AllStoriesItemListFragment();
		Bundle arguments = new Bundle();
		arguments.putInt("currentState", currentState);
        arguments.putStringArrayList("feedIds", feedIds);
		arguments.putSerializable("storyOrder", storyOrder);
        arguments.putSerializable("defaultFeedView", defaultFeedView);
		everythingFragment.setArguments(arguments);

		return everythingFragment;
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
        if (getActivity().isFinishing()) return;
		Intent i = new Intent(getActivity(), AllStoriesReading.class);
		i.putExtra(FeedReading.EXTRA_FEED_IDS, feedIds);
		i.putExtra(FeedReading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
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
