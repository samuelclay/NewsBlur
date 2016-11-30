package com.newsblur.fragment;

import android.content.Loader;
import android.database.Cursor;
import android.os.Bundle;

import com.newsblur.database.StoryItemsAdapter;

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
            adapter = new StoryItemsAdapter(getActivity(), cursor, false, false, false);
            itemList.setAdapter(adapter);
        }
        super.onLoadFinished(loader, cursor);
    }

}
