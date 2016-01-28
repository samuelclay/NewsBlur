package com.newsblur.fragment;

import android.content.Loader;
import android.database.Cursor;
import android.os.Bundle;
import android.view.ContextMenu;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.View;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.view.SocialItemViewBinder;

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
            String[] groupFrom = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_INTELLIGENCE_TOTAL, DatabaseConstants.FEED_TITLE };
            int[] groupTo = new int[] { R.id.row_item_title, R.id.row_item_content, R.id.row_item_author, R.id.row_item_date, R.id.row_item_sidebar, R.id.row_item_feedtitle };
            adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_folderitem, cursor, groupFrom, groupTo, true);
            adapter.setViewBinder(new SocialItemViewBinder(getActivity(), true));
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
