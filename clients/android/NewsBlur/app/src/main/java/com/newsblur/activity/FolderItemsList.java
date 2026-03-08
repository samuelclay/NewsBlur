package com.newsblur.activity;

import android.graphics.Bitmap;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.domain.CustomIcon;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.fragment.DeleteFolderDialogFragment;
import com.newsblur.fragment.RenameDialogFragment;
import com.newsblur.util.CustomIconRenderer;
import com.newsblur.util.UIUtils;

import java.util.Set;

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

    @Override
    protected boolean prepareItemListMenuModel(Menu menu) {
        super.prepareItemListMenuModel(menu);
        updateFolderMuteActions(menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (super.onOptionsItemSelected(item)) {
            return true;
        }

        if (item.getItemId() == R.id.menu_rename_folder) {
            showRenameFolderDialog();
            return true;
        }

        if (item.getItemId() == R.id.menu_mute_folder) {
            Set<String> feedIds = fs.getAllFeeds();
            if (feedIds != null && !feedIds.isEmpty()) {
                feedUtils.muteFeeds(this, feedIds);
            }
            return true;
        }

        if (item.getItemId() == R.id.menu_unmute_folder) {
            Set<String> feedIds = fs.getAllFeeds();
            if (feedIds != null && !feedIds.isEmpty()) {
                feedUtils.unmuteFeeds(this, feedIds);
            }
            return true;
        }

        if (item.getItemId() == R.id.menu_delete_folder) {
            showDeleteFolderDialog();
            return true;
        }

        return false;
    }

    private void showRenameFolderDialog() {
        String folderParentName = getFolderParentName();
        RenameDialogFragment renameDialogFragment = RenameDialogFragment.newFolderInstance(folderName, folderParentName);
        renameDialogFragment.show(getSupportFragmentManager(), RenameDialogFragment.class.getName());
    }

    private void showDeleteFolderDialog() {
        String folderParentName = getFolderParentName();
        DeleteFolderDialogFragment deleteFolderDialogFragment = DeleteFolderDialogFragment.newInstance(folderName, folderParentName);
        deleteFolderDialogFragment.show(getSupportFragmentManager(), DeleteFolderDialogFragment.class.getName());
    }

    private String getFolderParentName() {
        Folder folder = dbHelper.getFolder(folderName);
        return folder != null ? folder.getFirstParentName() : null;
    }

    private void updateFolderMuteActions(Menu menu) {
        MenuItem muteItem = menu.findItem(R.id.menu_mute_folder);
        MenuItem unmuteItem = menu.findItem(R.id.menu_unmute_folder);
        if (muteItem == null || unmuteItem == null) return;

        Set<String> feedIds = fs.getAllFeeds();
        if (feedIds == null || feedIds.isEmpty()) {
            muteItem.setVisible(false);
            unmuteItem.setVisible(false);
            return;
        }

        boolean hasActiveFeed = false;
        for (String feedId : feedIds) {
            Feed feed = dbHelper.getFeed(feedId);
            if (feed != null && feed.active) {
                hasActiveFeed = true;
                break;
            }
        }

        muteItem.setVisible(hasActiveFeed);
        unmuteItem.setVisible(!hasActiveFeed);
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
