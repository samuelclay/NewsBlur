package com.newsblur.fragment;

import java.util.ArrayList;

import android.content.ContentResolver;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
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
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.FolderReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.domain.Folder;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.FeedItemViewBinder;

public class FolderItemListFragment extends ItemListFragment implements OnItemClickListener {

	private ContentResolver contentResolver;
	private String folderName;
	private Folder folder;
	
	public static FolderItemListFragment newInstance(String folderName, StateFilter currentState, DefaultFeedView defaultFeedView) {
		FolderItemListFragment feedItemFragment = new FolderItemListFragment();

		Bundle args = new Bundle();
		args.putSerializable("currentState", currentState);
		args.putString("folderName", folderName);
        args.putSerializable("defaultFeedView", defaultFeedView);
		feedItemFragment.setArguments(args);

		return feedItemFragment;
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		folderName = getArguments().getString("folderName");
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        setupBezelSwipeDetector(itemList);

		itemList.setEmptyView(v.findViewById(R.id.empty_view));

		contentResolver = getActivity().getContentResolver();

		Cursor cursor = dbHelper.getStoriesCursor(getFeedSet(), currentState);
		getActivity().startManagingCursor(cursor);

		String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.FEED_TITLE, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, DatabaseConstants.STORY_AUTHORS };
		int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_feedtitle, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_author };

		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);

		adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_folderitem, cursor, groupFrom, groupTo, CursorAdapter.FLAG_REGISTER_CONTENT_OBSERVER);

		itemList.setOnScrollListener(this);

		adapter.setViewBinder(new FeedItemViewBinder(getActivity()));
		itemList.setAdapter(adapter);
		itemList.setOnItemClickListener(this);
		itemList.setOnCreateContextMenuListener(this);

		return v;
	}

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
        if (getActivity().isFinishing()) return;
		Intent i = new Intent(getActivity(), FolderReading.class);
        i.putExtra(Reading.EXTRA_FEEDSET, getFeedSet());
		i.putExtra(FeedReading.EXTRA_POSITION, position);
		i.putExtra(FeedReading.EXTRA_FOLDERNAME, folderName);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

}
