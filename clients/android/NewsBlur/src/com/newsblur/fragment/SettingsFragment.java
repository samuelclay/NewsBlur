package com.newsblur.fragment;

import android.os.Build;
import android.os.Bundle;
import android.preference.PreferenceCategory;
import android.preference.PreferenceFragment;
import android.preference.PreferenceManager;

import com.newsblur.R;
import com.newsblur.util.PrefConstants;

public class SettingsFragment extends PreferenceFragment {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        PreferenceManager preferenceManager = getPreferenceManager();
        preferenceManager.setSharedPreferencesName(PrefConstants.PREFERENCES);
        addPreferencesFromResource(R.xml.activity_settings);

        // Remove the reading category of references on pre-4.4 devices as it only contains
        // the single tap for immersive preference
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
            PreferenceCategory readingCategory = (PreferenceCategory)findPreference("reading");
            getPreferenceScreen().removePreference(readingCategory);
        }
    }

}
