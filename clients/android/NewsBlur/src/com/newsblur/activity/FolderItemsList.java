package com.newsblur.activity;

import java.util.ArrayList;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;
import android.widget.Toast;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.fragment.FolderItemListFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment.MarkAllReadDialogListener;
import com.newsblur.network.APIManager;
import com.newsblur.network.MarkFolderAsReadTask;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class FolderItemsList extends ItemsList implements MarkAllReadDialogListener {

	public static final String EXTRA_FOLDER_NAME = "folderName";
	private String folderName;
	private ArrayList<String> feedIds;
	private APIManager apiManager;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		folderName = getIntent().getStringExtra(EXTRA_FOLDER_NAME);

		setTitle(folderName);

		feedIds = new ArrayList<String>();

		apiManager = new APIManager(this);

		final Uri feedsUri = FeedProvider.FEED_FOLDER_MAP_URI.buildUpon().appendPath(folderName).build();
		Cursor cursor = getContentResolver().query(feedsUri, new String[] { DatabaseConstants.FEED_ID }, DatabaseConstants.getStorySelectionFromState(currentState), null, null);

		while (cursor.moveToNext() && (feedIds.size() <= AppConstants.MAX_FEED_LIST_SIZE)) {
			feedIds.add(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ID)));
		}

		itemListFragment = (FolderItemListFragment) fragmentManager.findFragmentByTag(FolderItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = FolderItemListFragment.newInstance(feedIds, folderName, currentState, getStoryOrder(), getDefaultFeedView());
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, FolderItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		MenuInflater inflater = getSupportMenuInflater();
		inflater.inflate(R.menu.itemslist, menu);
		return true;
	}

	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setSupportProgressBarIndeterminateVisibility(true);

			String[] feeds = new String[feedIds.size()];
			feedIds.toArray(feeds);
            FeedUtils.updateFeeds(this, this, feeds, page, getStoryOrder(), PrefsUtils.getReadFilterForFolder(this, folderName));
		}
	}


	@Override
	public void markItemListAsRead() {
	    MarkAllReadDialogFragment dialog = MarkAllReadDialogFragment.newInstance(folderName);
	    dialog.show(fragmentManager, "dialog");
	}

    @Override
    protected StoryOrder getStoryOrder() {
        return PrefsUtils.getStoryOrderForFolder(this, folderName);
    }

    @Override
    public void updateStoryOrderPreference(StoryOrder newValue) {
        PrefsUtils.setStoryOrderForFolder(this, folderName, newValue);
    }
    
    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        PrefsUtils.setReadFilterForFolder(this, folderName, newValue);
    }

    @Override
    protected ReadFilter getReadFilter() {
        return PrefsUtils.getReadFilterForFolder(this, folderName);
    }

    @Override
    protected DefaultFeedView getDefaultFeedView() {
        return PrefsUtils.getDefaultFeedViewForFolder(this, folderName);
    }

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFolder(this, folderName, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }

    @Override
    public void onMarkAllRead() {
        new MarkFolderAsReadTask(apiManager, getContentResolver()) {
            @Override
            protected void onPostExecute(Boolean result) {
                if (result) {
                    setResult(RESULT_OK);
                    Toast.makeText(FolderItemsList.this, R.string.toast_marked_folder_as_read, Toast.LENGTH_SHORT).show();
                    finish();
                } else {
                    Toast.makeText(FolderItemsList.this, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_SHORT).show();
                }
            }
        }.execute(folderName);
    }

    @Override
    public void onCancel() {
        // do nothing
    }
}
