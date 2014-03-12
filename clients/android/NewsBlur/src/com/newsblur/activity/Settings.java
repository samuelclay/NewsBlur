package com.newsblur.activity;

import com.newsblur.R;
import com.newsblur.util.PrefConstants;

import android.os.Bundle;
import android.preference.PreferenceActivity;
import android.view.MenuItem;

public class Settings extends PreferenceActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getActionBar().setDisplayHomeAsUpEnabled(true);
        super.getPreferenceManager().setSharedPreferencesName(PrefConstants.PREFERENCES);
        addPreferencesFromResource(R.layout.activity_settings);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
        case android.R.id.home:
            finish();
            return true;
        default:
            return super.onOptionsItemSelected(item);   
        }
    }
}
