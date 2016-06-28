package com.newsblur.fragment;

import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;

import com.newsblur.database.StoryItemsAdapter;

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
            adapter = new StoryItemsAdapter(getActivity(), cursor, getFeedSet().isFilterSaved(), getFeedSet().isFilterSaved(), false);
            itemList.setAdapter(adapter);
       }
       super.onLoadFinished(loader, cursor);
    }

}
