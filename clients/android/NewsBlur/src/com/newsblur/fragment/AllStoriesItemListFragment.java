package com.newsblur.fragment;

import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;
import android.view.View;
import android.widget.AdapterView;

import com.newsblur.R;
import com.newsblur.activity.AllStoriesReading;
import com.newsblur.activity.FeedReading;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.SocialItemViewBinder;

public class AllStoriesItemListFragment extends ItemListFragment {

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.SUM_STORY_TOTAL, DatabaseConstants.FEED_TITLE };
            int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_author, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_feedtitle };
            adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_folderitem, cursor, groupFrom, groupTo);
            adapter.setViewBinder(new SocialItemViewBinder(getActivity()));
            itemList.setAdapter(adapter);
        }
        super.onLoadFinished(loader, cursor);
    }

	public static ItemListFragment newInstance(StateFilter currentState, DefaultFeedView defaultFeedView) {
		ItemListFragment everythingFragment = new AllStoriesItemListFragment();
		Bundle arguments = new Bundle();
		arguments.putSerializable("currentState", currentState);
        arguments.putSerializable("defaultFeedView", defaultFeedView);
		everythingFragment.setArguments(arguments);

		return everythingFragment;
	}

	@Override
	public void onItemClick_(AdapterView<?> parent, View view, int position, long id) {
        if (getActivity().isFinishing()) return;
		Intent i = new Intent(getActivity(), AllStoriesReading.class);
        i.putExtra(Reading.EXTRA_FEEDSET, getFeedSet());
		i.putExtra(FeedReading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

}
