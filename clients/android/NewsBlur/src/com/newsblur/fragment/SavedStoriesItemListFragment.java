package com.newsblur.fragment;

import android.app.LoaderManager;
import android.content.ContentResolver;
import android.content.CursorLoader;
import android.content.Intent;
import android.content.Loader;
import android.database.Cursor;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.CursorAdapter;
import android.widget.ListView;
import android.widget.SimpleCursorAdapter;

import com.newsblur.R;
import com.newsblur.activity.Reading;
import com.newsblur.activity.SavedStoriesReading;
import com.newsblur.activity.FeedReading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.SocialItemViewBinder;

public class SavedStoriesItemListFragment extends ItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener {

	private ContentResolver contentResolver;
	
	public static int ITEMLIST_LOADER = 0x01;

    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

        defaultFeedView = (DefaultFeedView)getArguments().getSerializable("defaultFeedView");
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        setupBezelSwipeDetector(itemList);

		itemList.setEmptyView(v.findViewById(R.id.empty_view));

		contentResolver = getActivity().getContentResolver();
		Cursor cursor = contentResolver.query(FeedProvider.STARRED_STORIES_URI, null, null, null, DatabaseConstants.STARRED_STORY_ORDER);
		
		String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, DatabaseConstants.FEED_TITLE };
		int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_author, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_feedtitle };

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);

		adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_socialitem, cursor, groupFrom, groupTo, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER, true);

		itemList.setOnScrollListener(this);

		adapter.setViewBinder(new SocialItemViewBinder(getActivity(), true));
		itemList.setAdapter(adapter);
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
        ; // This fragment ignores state
	}

	public static ItemListFragment newInstance(DefaultFeedView defaultFeedView) {
		ItemListFragment fragment = new SavedStoriesItemListFragment();
        Bundle args = new Bundle();
        args.putSerializable("defaultFeedView", defaultFeedView);
        fragment.setArguments(args);
		return fragment;
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
        if (getActivity().isFinishing()) return;
		Intent i = new Intent(getActivity(), SavedStoriesReading.class);
		i.putExtra(FeedReading.EXTRA_POSITION, position);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

	@Override
	public Loader<Cursor> onCreateLoader(int arg0, Bundle arg1) {
		return new CursorLoader(getActivity(), FeedProvider.STARRED_STORIES_URI, null, null, null, DatabaseConstants.STARRED_STORY_ORDER);
	}

	@Override
    public void setStoryOrder(StoryOrder storyOrder) {
        ; // This fragment ignores story order
    }
}
