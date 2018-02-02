package com.newsblur.activity;

import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class FolderItemsList extends ItemsList {

	public static final String EXTRA_FOLDER_NAME = "folderName";
	private String folderName;

	@Override
	protected void onCreate(Bundle bundle) {
		folderName = getIntent().getStringExtra(EXTRA_FOLDER_NAME);

		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, R.drawable.g_icn_folder_rss, folderName);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.itemslist, menu);
		return true;
	}

}
