package com.newsblur.activity;

import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class GlobalSharedStoriesItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, R.drawable.ak_icon_global, getResources().getString(R.string.global_shared_stories_title));
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.allsocialstories_itemslist, menu);
        return true;
	}

}
