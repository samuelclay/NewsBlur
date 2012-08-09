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
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.view.ItemViewBinder;

public class FeedItemListFragment extends ItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener {
	
	private static final String TAG = "itemListFragment";
	public static final String FRAGMENT_TAG = "itemListFragment";
	private ContentResolver contentResolver;
	private String feedId;
	private SimpleCursorAdapter adapter;
	private Uri storiesUri;
	private int currentState;

	public static int ITEMLIST_LOADER = 0x01;
	private int READING_RETURNED = 0x02;

	public FeedItemListFragment(final String feedId, final int currentState) {
		this.feedId = feedId;
		this.currentState = currentState;
	}
	
	public FeedItemListFragment() {
		
	}
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	public static FeedItemListFragment newInstance(final String feedId, int currentState) {
		return new FeedItemListFragment(feedId, currentState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
		
		contentResolver = getActivity().getContentResolver();
		storiesUri = FeedProvider.STORIES_URI.buildUpon().appendPath(feedId).build();
		Cursor cursor = contentResolver.query(storiesUri, null, FeedProvider.getSelectionFromState(currentState), null, DatabaseConstants.STORY_DATE + " DESC");
		
		String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_READ, DatabaseConstants.STORY_SHORTDATE, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS };
		int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_author, R.id.row_item_title, R.id.row_item_date, R.id.row_item_sidebar };

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);
				
		adapter = new SimpleCursorAdapter(getActivity(), R.layout.row_item, cursor, groupFrom, groupTo, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);
		
		adapter.setViewBinder(new ItemViewBinder());
		itemList.setAdapter(adapter);
		itemList.setOnItemClickListener(this);
		
		return v;
	}

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
		Uri uri = FeedProvider.STORIES_URI.buildUpon().appendPath(feedId).build();
		CursorLoader cursorLoader = new CursorLoader(getActivity(), uri, null, FeedProvider.getSelectionFromState(currentState), null, DatabaseConstants.STORY_DATE + " DESC");
	    return cursorLoader;
	}

	@Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
		if (cursor != null) {
			adapter.swapCursor(cursor);
		}
	}
	
	public void hasUpdated() {
		getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
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
		final String selection = FeedProvider.getSelectionFromState(state);
		Cursor cursor = contentResolver.query(storiesUri, null, selection, null, DatabaseConstants.STORY_DATE + " DESC");
		adapter.swapCursor(cursor);
	}

	

}
