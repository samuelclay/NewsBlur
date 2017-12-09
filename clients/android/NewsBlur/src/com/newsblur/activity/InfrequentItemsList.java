package com.newsblur.activity;

import android.app.FragmentTransaction;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;

import com.newsblur.R;
import com.newsblur.fragment.InfrequentCutoffDialogFragment;
import com.newsblur.fragment.InfrequentCutoffDialogFragment.InfrequentCutoffChangedListener;
import com.newsblur.fragment.InfrequentItemListFragment;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

public class InfrequentItemsList extends ItemsList implements InfrequentCutoffChangedListener {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, R.drawable.ak_icon_allstories, getResources().getString(R.string.infrequent_title));

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

    @Override
	public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == R.id.menu_infrequent_cutoff) {
			InfrequentCutoffDialogFragment dialog = InfrequentCutoffDialogFragment.newInstance(PrefsUtils.getInfrequentCutoff(this));
			dialog.show(getFragmentManager(), InfrequentCutoffDialogFragment.class.getName());
			return true;
        } else {
            return super.onOptionsItemSelected(item);
        }
    }

    @Override
    public void infrequentCutoffChanged(int newValue) {
        PrefsUtils.setInfrequentCutoff(this, newValue);
        itemListFragment.resetEmptyState();
        itemListFragment.hasUpdated();
        itemListFragment.scrollToTop();
        FeedUtils.dbHelper.clearInfrequentSession();
        NBSyncService.resetReadingSession();
        NBSyncService.resetFetchState(fs);
        triggerSync();
    }

}
