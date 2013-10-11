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
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.AbsListView.OnScrollListener;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.activity.SocialFeedReading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.SocialItemViewBinder;

public class SocialFeedItemListFragment extends ItemListFragment implements LoaderManager.LoaderCallbacks<Cursor>, OnItemClickListener, OnScrollListener {

	private ContentResolver contentResolver;
	private String userId, username;
	private SimpleCursorAdapter adapter;
	private Uri storiesUri;
	private SocialFeed socialFeed;
	private int currentState, currentPage = 1;
	private boolean requestedPage;
	
	public static int ITEMLIST_LOADER = 0x01;
	private Uri socialFeedUri;
	private String[] groupFroms;
	private int[] groupTos;
	private ListView itemList;
    private StoryOrder storyOrder;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		currentState = getArguments().getInt("currentState");
        userId = getArguments().getString("userId");
        username = getArguments().getString("username");
        storyOrder = (StoryOrder)getArguments().getSerializable("storyOrder");
		contentResolver = getActivity().getContentResolver();
		storiesUri = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
		
		setupSocialFeed();
		
		groupFroms = new String[] { DatabaseConstants.FEED_FAVICON_URL, DatabaseConstants.FEED_TITLE, DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORTDATE, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS};
		groupTos = new int[] { R.id.row_item_feedicon, R.id.row_item_feedtitle, R.id.row_item_title, R.id.row_item_date, R.id.row_item_author, R.id.row_item_sidebar};

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);
		
	}

	private void setupSocialFeed() {
		socialFeedUri = FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(userId).build();
		socialFeed = SocialFeed.fromCursor(contentResolver.query(socialFeedUri, null, null, null, null));
	}
	
	public static SocialFeedItemListFragment newInstance(final String userId, final String username, final int currentState, final StoryOrder storyOrder) {
	    SocialFeedItemListFragment fragment = new SocialFeedItemListFragment();
		Bundle args = new Bundle();
        args.putInt("currentState", currentState);
        args.putString("userId", userId);
        args.putString("username", username);
        args.putSerializable("storyOrder", storyOrder);
        fragment.setArguments(args);
        return fragment;
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
		itemList.setEmptyView(v.findViewById(R.id.empty_view));
		
		itemList.setOnScrollListener(this);
		itemList.setAdapter(adapter);
		itemList.setOnItemClickListener(this);
		
		return v;
	}

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
		Uri uri = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
		CursorLoader cursorLoader = new CursorLoader(getActivity(), uri, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySharedSortOrder(storyOrder));
	    return cursorLoader;
	}

	@Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
		if (adapter == null) {
			adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_socialitem, cursor, groupFroms, groupTos, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);
			adapter.setViewBinder(new SocialItemViewBinder(getActivity()));
			itemList.setAdapter(adapter);
		}
		
		if (cursor != null) {
			adapter.swapCursor(cursor);
		}
	}
	
	public void hasUpdated() {
		setupSocialFeed();
		getLoaderManager().restartLoader(ITEMLIST_LOADER , null, this);
		requestedPage = false;
	}

	@Override
	public void onLoaderReset(Loader<Cursor> loader) {
		adapter.notifyDataSetInvalidated();
	}
	
	@Override
	public void onScroll(AbsListView view, int firstVisible, int visibleCount, int totalCount) {
		if (firstVisible + visibleCount == totalCount) {
			if (!requestedPage) {
				currentPage += 1;
				requestedPage = true;
				((ItemsList) getActivity()).triggerRefresh(currentPage);
			} 
		}
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
		Intent i = new Intent(getActivity(), SocialFeedReading.class);
		i.putExtra(Reading.EXTRA_USERID, userId);
		i.putExtra(Reading.EXTRA_USERNAME, username);
		i.putExtra(Reading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
		startActivity(i);
	}

	public void changeState(int state) {
		currentState = state;
		final String selection = DatabaseConstants.getStorySelectionFromState(state);
		Cursor cursor = contentResolver.query(storiesUri, null, selection, null, DatabaseConstants.getStorySharedSortOrder(storyOrder));
		adapter.swapCursor(cursor);
		getActivity().startManagingCursor(cursor);
	}

	@Override
	public void onScrollStateChanged(AbsListView view, int scrollState) { }
	
	@Override
    public void setStoryOrder(StoryOrder storyOrder) {
        this.storyOrder = storyOrder;
    }
}
