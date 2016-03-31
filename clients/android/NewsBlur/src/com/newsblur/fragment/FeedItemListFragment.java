package com.newsblur.fragment;

import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedItemsAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.view.FeedItemViewBinder;

public class FeedItemListFragment extends ItemListFragment {

	private Feed feed;

    public static FeedItemListFragment newInstance(Feed feed) {
		FeedItemListFragment feedItemFragment = new FeedItemListFragment();
		Bundle args = new Bundle();
		args.putSerializable("feed", feed);
		feedItemFragment.setArguments(args);
		return feedItemFragment;
	}

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		feed = (Feed) getArguments().getSerializable("feed");
	}

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_INTELLIGENCE_TOTAL };
            int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_author, R.id.row_item_date, R.id.row_item_sidebar };
            adapter = new FeedItemsAdapter(getActivity(), feed, R.layout.row_item, cursor, groupFrom, groupTo, getFeedSet().isFilterSaved());
            adapter.setViewBinder(new FeedItemViewBinder(getActivity(), getFeedSet().isFilterSaved()));
            itemList.setAdapter(adapter);
       }
       super.onLoadFinished(loader, cursor);
    }

}
