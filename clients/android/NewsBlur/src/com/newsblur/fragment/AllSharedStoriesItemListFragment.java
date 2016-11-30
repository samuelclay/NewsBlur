package com.newsblur.fragment;

import android.content.Loader;
import android.database.Cursor;
import android.os.Bundle;

import com.newsblur.database.StoryItemsAdapter;

public class AllSharedStoriesItemListFragment extends ItemListFragment {

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            adapter = new StoryItemsAdapter(getActivity(), cursor, false, false, false);
            itemList.setAdapter(adapter);
        }
        super.onLoadFinished(loader, cursor);
    }

	public static ItemListFragment newInstance() {
		ItemListFragment everythingFragment = new AllSharedStoriesItemListFragment();
		Bundle arguments = new Bundle();
		everythingFragment.setArguments(arguments);
		return everythingFragment;
	}

}
