package com.newsblur.fragment;

import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;
import android.view.View;

import com.newsblur.R;
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.FolderReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.FeedItemViewBinder;

public class FolderItemListFragment extends ItemListFragment {

	private String folderName;
	
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
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.FEED_TITLE, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.SUM_STORY_TOTAL, DatabaseConstants.STORY_AUTHORS };
            int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_feedtitle, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_author };
            adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_folderitem, cursor, groupFrom, groupTo);
            adapter.setViewBinder(new FeedItemViewBinder(getActivity()));
            itemList.setAdapter(adapter);
       }
       super.onLoadFinished(loader, cursor);
    }

	@Override
	public void onItemClick_(String storyHash) {
		Intent i = new Intent(getActivity(), FolderReading.class);
        i.putExtra(Reading.EXTRA_STORY_HASH, storyHash);
        i.putExtra(Reading.EXTRA_FEEDSET, getFeedSet());
		i.putExtra(FeedReading.EXTRA_FOLDERNAME, folderName);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

}
