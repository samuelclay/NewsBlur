package com.newsblur.fragment;

import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.view.FeedItemViewBinder;

public class FolderItemListFragment extends ItemListFragment {

	public static FolderItemListFragment newInstance() {
		FolderItemListFragment feedItemFragment = new FolderItemListFragment();
		Bundle args = new Bundle();
		feedItemFragment.setArguments(args);
		return feedItemFragment;
	}

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.FEED_TITLE, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_INTELLIGENCE_TOTAL, DatabaseConstants.STORY_AUTHORS };
            int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_feedtitle, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_author };
            adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_folderitem, cursor, groupFrom, groupTo);
            adapter.setViewBinder(new FeedItemViewBinder(getActivity()));
            itemList.setAdapter(adapter);
       }
       super.onLoadFinished(loader, cursor);
    }

}
