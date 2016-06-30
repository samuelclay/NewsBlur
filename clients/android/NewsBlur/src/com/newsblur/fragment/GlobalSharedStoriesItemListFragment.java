package com.newsblur.fragment;

import android.content.Loader;
import android.database.Cursor;
import android.os.Bundle;
import android.view.ContextMenu;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.View;

import com.newsblur.R;
import com.newsblur.database.StoryItemsAdapter;

public class GlobalSharedStoriesItemListFragment extends ItemListFragment {

	public static ItemListFragment newInstance() {
		ItemListFragment fragment = new GlobalSharedStoriesItemListFragment();
        Bundle args = new Bundle();
        fragment.setArguments(args);
		return fragment;
	}

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            adapter = new StoryItemsAdapter(getActivity(), cursor, true, true, false);
            itemList.setAdapter(adapter);
       }
       super.onLoadFinished(loader, cursor);
    }

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
        super.onCreateContextMenu(menu, v, menuInfo);
        menu.removeItem(R.id.menu_mark_story_as_read);
        menu.removeItem(R.id.menu_mark_story_as_unread);
        menu.removeItem(R.id.menu_mark_newer_stories_as_read);
        menu.removeItem(R.id.menu_mark_older_stories_as_read);
    }

}
