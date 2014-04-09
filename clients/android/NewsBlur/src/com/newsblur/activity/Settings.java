package com.newsblur.activity;

import com.newsblur.R;
import com.newsblur.util.PrefConstants;

import android.os.Build;
import android.os.Bundle;
import android.preference.PreferenceActivity;
import android.preference.PreferenceCategory;
import android.view.MenuItem;

public class Settings extends PreferenceActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getActionBar().setDisplayHomeAsUpEnabled(true);
        super.getPreferenceManager().setSharedPreferencesName(PrefConstants.PREFERENCES);
        addPreferencesFromResource(R.layout.activity_settings);

        // Remove the reading category of references on pre-4.4 devices as it only contains
        // the single tap for immersive preference
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            PreferenceCategory readingCategory = (PreferenceCategory)findPreference("reading");
            getPreferenceScreen().removePreference(readingCategory);
        }
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
