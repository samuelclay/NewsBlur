package com.newsblur.activity;

import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class SavedStoriesItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        String title = getResources().getString(R.string.saved_stories_title);
        if (fs.getSingleSavedTag() != null) {
            title = title + " - " + fs.getSingleSavedTag();
        }
        UIUtils.setCustomActionBar(this, R.drawable.clock, title);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.savedstories_itemslist, menu);
        return true;
	}

}
