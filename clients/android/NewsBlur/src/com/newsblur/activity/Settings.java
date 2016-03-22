package com.newsblur.activity;

import com.newsblur.R;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.preference.PreferenceActivity;
import android.preference.PreferenceCategory;
import android.preference.PreferenceManager;
import android.view.MenuItem;

public class Settings extends PreferenceActivity implements SharedPreferences.OnSharedPreferenceChangeListener {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        PrefsUtils.applyThemePreference(this);

        super.onCreate(savedInstanceState);
        getActionBar().setDisplayHomeAsUpEnabled(true);
        PreferenceManager preferenceManager = super.getPreferenceManager();
        preferenceManager.setSharedPreferencesName(PrefConstants.PREFERENCES);
        SharedPreferences prefs = getSharedPreferences(PrefConstants.PREFERENCES, 0);
        prefs.registerOnSharedPreferenceChangeListener(this);
        addPreferencesFromResource(R.xml.activity_settings);

        // Remove the reading category of references on pre-4.4 devices as it only contains
        // the single tap for immersive preference
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            PreferenceCategory readingCategory = (PreferenceCategory)findPreference("reading");
            getPreferenceScreen().removePreference(readingCategory);
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();

        SharedPreferences prefs = getSharedPreferences(PrefConstants.PREFERENCES, 0);
        prefs.unregisterOnSharedPreferenceChangeListener(this);
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

    @Override
    public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
        if (key.equals(PrefConstants.THEME)) {
            UIUtils.restartActivity(this);
        }
    }
}
