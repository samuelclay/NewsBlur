package com.newsblur.activity;

import android.graphics.Bitmap;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.domain.CustomIcon;
import com.newsblur.util.CustomIconRenderer;
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
		CustomIcon customIcon = BlurDatabaseHelper.getFolderIcon(folderName);
		if (customIcon != null) {
			int iconSize = UIUtils.dp2px(this, 24);
			Bitmap iconBitmap = CustomIconRenderer.renderIcon(this, customIcon, iconSize);
			if (iconBitmap != null) {
				UIUtils.setupToolbar(this, iconBitmap, folderName, false);
				return;
			}
		}
		UIUtils.setupToolbar(this, R.drawable.ic_folder_closed, folderName, false);
	}
}
