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
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedItemsAdapter;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Feed;
import com.newsblur.util.AppConstants;
import com.newsblur.util.NetworkUtils;
import com.newsblur.view.FeedItemViewBinder;

public class FeedItemListFragment extends ItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener, OnScrollListener {

	private static final String TAG = "itemListFragment";
	public static final String FRAGMENT_TAG = "itemListFragment";
	private ContentResolver contentResolver;
	private String feedId;
	private SimpleCursorAdapter adapter;
	private Uri storiesUri;
	private int currentState;
	private int currentPage = 1;
	private boolean requestedPage = false;
	private boolean doRequest = true;

	public static int ITEMLIST_LOADER = 0x01;
	private int READING_RETURNED = 0x02;
	private Feed feed;
	private Cursor feedCursor;

	public static FeedItemListFragment newInstance(String feedId, int currentState) {
		FeedItemListFragment feedItemFragment = new FeedItemListFragment();
		
		Bundle args = new Bundle();
		args.putInt("currentState", currentState);
		args.putString("feedId", feedId);
		feedItemFragment.setArguments(args);

		return feedItemFragment;
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		currentState = getArguments().getInt("currentState");
		feedId = getArguments().getString("feedId");
		
		if (!NetworkUtils.isOnline(getActivity())) {
			doRequest = false;
		}
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);

		itemList.setEmptyView(v.findViewById(R.id.empty_view));
		
		contentResolver = getActivity().getContentResolver();
		storiesUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
		Cursor cursor = contentResolver.query(storiesUri, null, FeedProvider.getStorySelectionFromState(currentState), null, DatabaseConstants.STORY_DATE + " DESC");
		
		setupFeed();

		String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_READ, DatabaseConstants.STORY_SHORTDATE, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS };
		int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_author, R.id.row_item_title, R.id.row_item_date, R.id.row_item_sidebar };

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);

		adapter = new FeedItemsAdapter(getActivity(), feed, R.layout.row_item, cursor, groupFrom, groupTo, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);

		itemList.setOnScrollListener(this);
		
		adapter.setViewBinder(new FeedItemViewBinder(getActivity()));
		itemList.setAdapter(adapter);
		itemList.setOnItemClickListener(this);

		return v;
	}

	private void setupFeed() {
		Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		feedCursor = contentResolver.query(feedUri, null, null, null, null);
		feedCursor.moveToFirst();
		feed = Feed.fromCursor(feedCursor);
	}

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
		Uri uri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
		CursorLoader cursorLoader = new CursorLoader(getActivity(), uri, null, FeedProvider.getStorySelectionFromState(currentState), null, DatabaseConstants.STORY_DATE + " DESC");
		return cursorLoader;
	}

	@Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
		if (cursor != null) {
			adapter.swapCursor(cursor);
		}
	}

	public void hasUpdated() {
		setupFeed();
		getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
		requestedPage = false;
	}

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		Log.d(TAG, "Loader reset");
		adapter.notifyDataSetInvalidated();
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
		Intent i = new Intent(getActivity(), FeedReading.class);
		i.putExtra(Reading.EXTRA_FEED, feedId);
		i.putExtra(FeedReading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
		startActivityForResult(i, READING_RETURNED );
	}

	public void changeState(int state) {
		currentState = state;
		final String selection = FeedProvider.getStorySelectionFromState(state);
		Cursor cursor = contentResolver.query(storiesUri, null, selection, null, DatabaseConstants.STORY_DATE + " DESC");
		adapter.swapCursor(cursor);
	}

	@Override
	public void onScroll(AbsListView view, int firstVisible, int visibleCount, int totalCount) {
		if (firstVisible + visibleCount == totalCount) {
			boolean loadMore = false;
			
			switch (currentState) {
			case AppConstants.STATE_ALL:
				loadMore = feed.positiveCount + feed.neutralCount + feed.negativeCount > totalCount;
				break;
			case AppConstants.STATE_BEST:
				loadMore = feed.positiveCount > totalCount;
				break;
			case AppConstants.STATE_SOME:
				loadMore = feed.positiveCount + feed.neutralCount > totalCount;
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
	public void onScrollStateChanged(AbsListView view, int scrollState) { }



}
