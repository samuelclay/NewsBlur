package com.newsblur.activity;

import android.app.FragmentTransaction;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;

import com.newsblur.R;
import com.newsblur.fragment.InfrequentItemListFragment;
import com.newsblur.util.UIUtils;

public class InfrequentItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, R.drawable.ak_icon_allstories, getResources().getString(R.string.infrequent_row_title));

		itemListFragment = (InfrequentItemListFragment) fragmentManager.findFragmentByTag(InfrequentItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = InfrequentItemListFragment.newInstance();
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, InfrequentItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.infrequent_itemslist, menu);
        return true;
	}

}
