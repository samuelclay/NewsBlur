package com.newsblur.fragment;

import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;

import com.newsblur.database.StoryItemsAdapter;
import com.newsblur.domain.Feed;

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
            adapter = new StoryItemsAdapter(getActivity(), cursor, getFeedSet().isFilterSaved(), getFeedSet().isFilterSaved(), true);
            itemList.setAdapter(adapter);
       }
       super.onLoadFinished(loader, cursor);
    }

}
