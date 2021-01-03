package com.newsblur.fragment;

import android.os.Bundle;

import androidx.preference.Preference;
import androidx.preference.PreferenceFragmentCompat;
import androidx.preference.PreferenceManager;

import com.newsblur.R;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;

public class SettingsFragment extends PreferenceFragmentCompat {

    private Preference deleteOfflineStoriesPref;

    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
        PreferenceManager preferenceManager = getPreferenceManager();
        preferenceManager.setSharedPreferencesName(PrefConstants.PREFERENCES);
        setPreferencesFromResource(R.xml.activity_settings, rootKey);

        deleteOfflineStoriesPref = findPreference(getString(R.string.menu_delete_offline_stories_key));
        if (deleteOfflineStoriesPref != null) {
            deleteOfflineStoriesPref.setOnPreferenceClickListener(preference -> {
                deleteOfflineStories();
                return true;
            });
        }
    }

    private void deleteOfflineStories() {
        if (deleteOfflineStoriesPref != null) {
            deleteOfflineStoriesPref.setOnPreferenceClickListener(null);
            FeedUtils.syncOfflineStories(requireContext());
            deleteOfflineStoriesPref.setSummary("");
            deleteOfflineStoriesPref.setTitle(R.string.menu_delete_offline_stories_confirmation);
        }
    }
}