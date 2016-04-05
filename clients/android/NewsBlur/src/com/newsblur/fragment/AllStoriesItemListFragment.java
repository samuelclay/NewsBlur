package com.newsblur.fragment;

import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.view.FeedItemViewBinder;

public class AllStoriesItemListFragment extends ItemListFragment {

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_INTELLIGENCE_TOTAL, DatabaseConstants.FEED_TITLE };
            int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_author, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_feedtitle };
            adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_folderitem, cursor, groupFrom, groupTo);
            adapter.setViewBinder(new FeedItemViewBinder(getActivity()));
            itemList.setAdapter(adapter);
        }
        super.onLoadFinished(loader, cursor);
    }

	public static ItemListFragment newInstance() {
		ItemListFragment everythingFragment = new AllStoriesItemListFragment();
		Bundle arguments = new Bundle();
		everythingFragment.setArguments(arguments);
		return everythingFragment;
	}

}
