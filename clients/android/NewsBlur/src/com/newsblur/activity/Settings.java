package com.newsblur.activity;

import com.actionbarsherlock.app.SherlockPreferenceActivity;
import com.newsblur.R;
import com.newsblur.util.PrefConstants;

import android.os.Bundle;

public class Settings extends SherlockPreferenceActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        super.getPreferenceManager().setSharedPreferencesName(PrefConstants.PREFERENCES);
        addPreferencesFromResource(R.layout.activity_settings);
    }

}
