package com.newsblur.fragment;

import android.os.Bundle;
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
    }

}
