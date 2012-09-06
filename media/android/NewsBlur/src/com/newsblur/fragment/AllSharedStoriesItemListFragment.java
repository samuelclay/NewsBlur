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
import android.widget.AbsListView;
import android.widget.AbsListView.OnScrollListener;
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
import com.newsblur.util.AppConstants;
import com.newsblur.util.NetworkUtils;
import com.newsblur.view.SocialItemViewBinder;

public class AllSharedStoriesItemListFragment extends ItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener, OnScrollListener {

	public int currentState;
	private boolean doRequest = true;
	private ContentResolver contentResolver;
	private SimpleCursorAdapter adapter;
	private boolean requestedPage;
	private int currentPage = 0;
	private int positiveCount, neutralCount, negativeCount;
	
	public static int ITEMLIST_LOADER = 0x01;
	private static final String TAG = "AllSharedStoriesItemListFragment";
	private Cursor countCursor;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		currentState = getArguments().getInt("currentState");
		
		if (!NetworkUtils.isOnline(getActivity())) {
			doRequest  = false;
		}
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);

		itemList.setEmptyView(v.findViewById(R.id.empty_view));
		
		contentResolver = getActivity().getContentResolver();
		Cursor cursor = contentResolver.query(FeedProvider.ALL_SHARED_STORIES_URI, null, FeedProvider.getSelectionFromState(currentState), null, null);
		calculateTotals();
		
		
		String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_READ, DatabaseConstants.STORY_SHORTDATE, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, DatabaseConstants.FEED_TITLE };
		int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_author, R.id.row_item_title, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_feedtitle };

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);

		adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_socialitem, cursor, groupFrom, groupTo, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);

		itemList.setOnScrollListener(this);
		
		adapter.setViewBinder(new SocialItemViewBinder(getActivity()));
		itemList.setAdapter(adapter);
		itemList.setOnItemClickListener(this);

		return v;
	}

	private void calculateTotals() {
		countCursor = contentResolver.query(FeedProvider.SOCIALCOUNT_URI, null, DatabaseConstants.SOCIAL_INTELLIGENCE_SOME, null, null);
		
		countCursor.moveToFirst();
		positiveCount = countCursor.getInt(countCursor.getColumnIndex(DatabaseConstants.SUM_NEG));
		neutralCount = countCursor.getInt(countCursor.getColumnIndex(DatabaseConstants.SUM_NEUT));
		negativeCount = countCursor.getInt(countCursor.getColumnIndex(DatabaseConstants.SUM_POS));
	}
	
	@Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
		if (cursor != null) {
			adapter.swapCursor(cursor);
		}
	}
	
	public void hasUpdated() {
		getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
		requestedPage = false;
	}

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		adapter.notifyDataSetInvalidated();
	}

	@Override
	public void changeState(int state) {
		currentState = state;
		calculateTotals();
		Cursor cursor = contentResolver.query(FeedProvider.ALL_SHARED_STORIES_URI, null, FeedProvider.getSelectionFromState(currentState), null, null);
		adapter.swapCursor(cursor);
	}

	public static ItemListFragment newInstance(int currentState) {
		ItemListFragment everythingFragment = new AllSharedStoriesItemListFragment();
		Bundle arguments = new Bundle();
		arguments.putInt("currentState", currentState);
		everythingFragment.setArguments(arguments);
		
		return everythingFragment;
	}

	@Override
	public void onScroll(AbsListView view, int firstVisible, int visibleCount, int totalCount) {
		if (firstVisible + visibleCount == totalCount) {
			boolean loadMore = false;
			
			switch (currentState) {
			case AppConstants.STATE_ALL:
				loadMore = positiveCount + neutralCount + negativeCount > totalCount;
				break;
			case AppConstants.STATE_BEST:
				loadMore = positiveCount > totalCount;
				break;
			case AppConstants.STATE_SOME:
				loadMore = positiveCount + neutralCount > totalCount;
				break;	
			}
	
			if (loadMore && !requestedPage && doRequest) {
				currentPage += 1;
				requestedPage = true;
				((ItemsList) getActivity()).triggerRefresh(currentPage);
			} else {
				Log.d(TAG, "No need");
			}
		}
	}

	@Override
	public void onScrollStateChanged(AbsListView arg0, int arg1) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
		Intent i = new Intent(getActivity(), AllStoriesReading.class);
		i.putExtra(FeedReading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
		startActivityForResult(i, READING_RETURNED );
	}

	@Override
	public Loader<Cursor> onCreateLoader(int arg0, Bundle arg1) {
		CursorLoader cursorLoader = new CursorLoader(getActivity(), FeedProvider.ALL_SHARED_STORIES_URI, null, FeedProvider.getSelectionFromState(currentState), null, null);
	    return cursorLoader;
	}


}
