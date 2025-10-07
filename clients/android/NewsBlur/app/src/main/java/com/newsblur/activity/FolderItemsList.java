package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class FolderItemsList extends ItemsList {

	public static final String EXTRA_FOLDER_NAME = "folderName";
	private String folderName;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		setupFolder(getIntent().getStringExtra(EXTRA_FOLDER_NAME));
		viewModel.getNextSession().observe(this, session ->
				setupFolder(session.getFolderName()));
	}

	@Override
	String getSaveSearchFeedId() {
		return "river:" + folderName;
	}

	private void setupFolder(String folderName) {
		this.folderName = folderName;
		UIUtils.setupToolbar(this, R.drawable.ic_folder_closed, folderName, false);
	}
}
