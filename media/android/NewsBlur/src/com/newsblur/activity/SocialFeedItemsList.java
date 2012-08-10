package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;

import com.newsblur.R;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SocialFeedItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;

public class SocialFeedItemsList extends ItemsList {

	private String username;
	private String userId;
	private String userIcon;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		username = getIntent().getStringExtra(EXTRA_BLURBLOG_USERNAME);
		userIcon = getIntent().getStringExtra(EXTRA_BLURBLOG_USER_ICON );
		userId = getIntent().getStringExtra(EXTRA_BLURBLOG_USERID);
		
		//		Drawable drawable = ((NewsBlurApplication) getApplication()).getImageLoader().getImage(userIcon, userId);
		//		getSupportActionBar().setLogo(drawable);
		
		setTitle(username);
		
		if (itemListFragment == null) {
			itemListFragment = SocialFeedItemListFragment.newInstance(userId, username, currentState);
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, FeedItemListFragment.FRAGMENT_TAG);
			listTransaction.commit();
		}
		
		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerRefresh();
		}
	}
	
	@Override
	public void triggerRefresh() {
		triggerRefresh(0);
	}

	@Override
	public void triggerRefresh(int page) {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_SOCIALFEED_UPDATE);
		intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_ID, userId);
		if (page > 1) {
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
		}
		intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_USERNAME, username);
		startService(intent);
	}

}
