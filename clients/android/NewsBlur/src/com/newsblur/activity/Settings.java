package com.newsblur.activity;

import android.content.SharedPreferences;
import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;

import com.newsblur.R;
import com.newsblur.databinding.ActivitySettingsBinding;
import com.newsblur.fragment.SettingsFragment;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class Settings extends AppCompatActivity implements SharedPreferences.OnSharedPreferenceChangeListener {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        PrefsUtils.applyThemePreference(this);
        super.onCreate(savedInstanceState);
        ActivitySettingsBinding binding = ActivitySettingsBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.settings), true);

        getSupportFragmentManager()
                .beginTransaction()
                .replace(binding.container.getId(), new SettingsFragment())
                .commit();

        SharedPreferences prefs = getSharedPreferences(PrefConstants.PREFERENCES, 0);
        prefs.registerOnSharedPreferenceChangeListener(this);
    }

    @Override
    protected void onDestroy() {
        SharedPreferences prefs = getSharedPreferences(PrefConstants.PREFERENCES, 0);
        prefs.unregisterOnSharedPreferenceChangeListener(this);
        super.onDestroy();

    }

    @Override
    public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
        if (key.equals(PrefConstants.THEME)) {
            UIUtils.restartActivity(this);
        }
    }
}
