package com.newsblur.fragment;

import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;
import android.view.View;

import com.newsblur.R;
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedItemsAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.ReadFilter;
import com.newsblur.view.FeedItemViewBinder;

public class FeedItemListFragment extends ItemListFragment {

	private Feed feed;

    public static FeedItemListFragment newInstance(Feed feed, StateFilter currentState, DefaultFeedView defaultFeedView) {
		FeedItemListFragment feedItemFragment = new FeedItemListFragment();

		Bundle args = new Bundle();
		args.putSerializable("currentState", currentState);
		args.putSerializable("feed", feed);
        args.putSerializable("defaultFeedView", defaultFeedView);
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
            String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.SUM_STORY_TOTAL };
            int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_author, R.id.row_item_date, R.id.row_item_sidebar };
            adapter = new FeedItemsAdapter(getActivity(), feed, R.layout.row_item, cursor, groupFrom, groupTo);
            adapter.setViewBinder(new FeedItemViewBinder(getActivity()));
            itemList.setAdapter(adapter);
       }
       super.onLoadFinished(loader, cursor);
    }

	@Override
	public void onItemClick_(String storyHash) {
		Intent i = new Intent(getActivity(), FeedReading.class);
        i.putExtra(Reading.EXTRA_STORY_HASH, storyHash);
        i.putExtra(Reading.EXTRA_FEEDSET, getFeedSet());
		i.putExtra(Reading.EXTRA_FEED, feed);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

}
