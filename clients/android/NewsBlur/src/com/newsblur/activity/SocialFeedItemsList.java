package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;
import android.app.FragmentTransaction;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SocialFeedItemListFragment;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class SocialFeedItemsList extends ItemsList {

	private String userIcon, userId, username, title;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		username = getIntent().getStringExtra(EXTRA_BLURBLOG_USERNAME);
		userIcon = getIntent().getStringExtra(EXTRA_BLURBLOG_USER_ICON );
		userId = getIntent().getStringExtra(EXTRA_BLURBLOG_USERID);
		title = getIntent().getStringExtra(EXTRA_BLURBLOG_TITLE);
				
		setTitle(title);
		
		if (itemListFragment == null) {
			itemListFragment = SocialFeedItemListFragment.newInstance(userId, username, currentState, getDefaultFeedView());
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, SocialFeedItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

	@Override
    protected FeedSet createFeedSet() {
        //Log.d(this.getClass().getName(), "creating feedset social ID:" + getIntent().getStringExtra(EXTRA_BLURBLOG_USERID) + " name:" + getIntent().getStringExtra(EXTRA_BLURBLOG_USERNAME));
        return FeedSet.singleSocialFeed(getIntent().getStringExtra(EXTRA_BLURBLOG_USERID), getIntent().getStringExtra(EXTRA_BLURBLOG_USERNAME));
    }

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.itemslist, menu);
		return true;
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

    @Override
    protected DefaultFeedView getDefaultFeedView() {
        return PrefsUtils.getDefaultFeedViewForFeed(this, userId);
    }

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFeed(this, userId, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }
}
