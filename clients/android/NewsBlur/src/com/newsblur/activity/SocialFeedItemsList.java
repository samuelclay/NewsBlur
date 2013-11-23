package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;
import android.widget.Toast;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.newsblur.R;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SocialFeedItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.network.APIManager;
import com.newsblur.network.MarkSocialFeedAsReadTask;
import com.newsblur.service.SyncService;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class SocialFeedItemsList extends ItemsList {

	private String userIcon, userId, username, title;
	private APIManager apiManager;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		apiManager = new APIManager(this);
		
		username = getIntent().getStringExtra(EXTRA_BLURBLOG_USERNAME);
		userIcon = getIntent().getStringExtra(EXTRA_BLURBLOG_USER_ICON );
		userId = getIntent().getStringExtra(EXTRA_BLURBLOG_USERID);
		title = getIntent().getStringExtra(EXTRA_BLURBLOG_TITLE);
				
		setTitle(title);
		
		if (itemListFragment == null) {
			itemListFragment = SocialFeedItemListFragment.newInstance(userId, username, currentState, getStoryOrder());
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, SocialFeedItemListFragment.class.getName());
			listTransaction.commit();
		}
		
		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerRefresh(1);
		}
	}
	

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getSupportMenuInflater();
		inflater.inflate(R.menu.itemslist, menu);
		return true;
	}
	
	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setSupportProgressBarIndeterminateVisibility(true);
			final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
			intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
			intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.SOCIALFEED_UPDATE);
			intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_ID, userId);
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
			intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_USERNAME, username);
			intent.putExtra(SyncService.EXTRA_TASK_ORDER, getStoryOrder());
            intent.putExtra(SyncService.EXTRA_TASK_READ_FILTER, PrefsUtils.getReadFilterForFeed(this, userId));
			startService(intent);
		}
	}

	@Override
	public void markItemListAsRead() {
		new MarkSocialFeedAsReadTask(apiManager, getContentResolver()){
			@Override
			protected void onPostExecute(Boolean result) {
				if (result.booleanValue()) {
					setResult(RESULT_OK);
					Toast.makeText(SocialFeedItemsList.this, R.string.toast_marked_socialfeed_as_read, Toast.LENGTH_SHORT).show();
					finish();
				} else {
					Toast.makeText(SocialFeedItemsList.this, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_LONG).show();
				}
			}
		}.execute(userId);
	}

    @Override
    protected StoryOrder getStoryOrder() {
        return PrefsUtils.getStoryOrderForFeed(this, userId);
    }

    @Override
    public void updateStoryOrderPreference(StoryOrder newValue) {
        PrefsUtils.setStoryOrderForFeed(this, userId, newValue);
    }
    
    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        PrefsUtils.setReadFilterForFeed(this, userId, newValue);
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        return PrefsUtils.getReadFilterForFeed(this, userId);
    }
}
