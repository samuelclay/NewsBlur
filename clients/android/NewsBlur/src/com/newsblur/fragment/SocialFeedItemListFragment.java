package com.newsblur.fragment;

import android.content.Loader;
import android.database.Cursor;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.view.FeedItemViewBinder;

public class SocialFeedItemListFragment extends ItemListFragment {

	public static SocialFeedItemListFragment newInstance() {
	    SocialFeedItemListFragment fragment = new SocialFeedItemListFragment();
		Bundle args = new Bundle();
        fragment.setArguments(args);
        return fragment;
	}
	
    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            String[] groupFroms = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.FEED_FAVICON_URL, DatabaseConstants.FEED_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_INTELLIGENCE_TOTAL};
            int[] groupTos = new int[] { R.id.row_item_title, R.id.row_item_feedicon, R.id.row_item_feedtitle, R.id.row_item_content, R.id.row_item_date, R.id.row_item_author, R.id.row_item_sidebar};
            adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_folderitem, cursor, groupFroms, groupTos);
            adapter.setViewBinder(new FeedItemViewBinder(getActivity()));
            itemList.setAdapter(adapter);
        }
        super.onLoadFinished(loader, cursor);
    }

}
