package com.newsblur.activity;

import android.os.Bundle;
import android.view.MenuItem;

import com.newsblur.R;
import com.newsblur.fragment.InfrequentCutoffDialogFragment;
import com.newsblur.fragment.InfrequentCutoffDialogFragment.InfrequentCutoffChangedListener;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

public class InfrequentItemsList extends ItemsList implements InfrequentCutoffChangedListener {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setupToolbar(this, R.drawable.ak_icon_infrequent, getResources().getString(R.string.infrequent_title), false);
	}

    @Override
	public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == R.id.menu_infrequent_cutoff) {
			InfrequentCutoffDialogFragment dialog = InfrequentCutoffDialogFragment.newInstance(PrefsUtils.getInfrequentCutoff(this));
			dialog.show(getSupportFragmentManager(), InfrequentCutoffDialogFragment.class.getName());
			return true;
        } else {
            return super.onOptionsItemSelected(item);
        }
    }

    @Override
    public void infrequentCutoffChanged(int newValue) {
        PrefsUtils.setInfrequentCutoff(this, newValue);
        dbHelper.clearInfrequentSession();
        restartReadingSession();
    }

    @Override
    String getSaveSearchFeedId() {
        return "river:infrequent";
    }
}
