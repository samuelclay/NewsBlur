package com.newsblur.activity

import android.content.SharedPreferences
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.newsblur.R
import com.newsblur.databinding.ActivitySettingsBinding
import com.newsblur.fragment.SettingsFragment
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.EdgeToEdgeUtil.applyTheme
import com.newsblur.util.PrefConstants
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class Settings : AppCompatActivity(), SharedPreferences.OnSharedPreferenceChangeListener {

    @Inject
    lateinit var prefsRepo: PrefsRepo

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyTheme(prefsRepo.getSelectedTheme())
        val binding = ActivitySettingsBinding.inflate(layoutInflater)
        applyView(binding)

        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.settings), true)

        supportFragmentManager
                .beginTransaction()
                .replace(binding.container.id, SettingsFragment())
                .commit()

        val prefs = getSharedPreferences(PrefConstants.PREFERENCES, 0)
        prefs.registerOnSharedPreferenceChangeListener(this)
    }

    override fun onDestroy() {
        val prefs = getSharedPreferences(PrefConstants.PREFERENCES, 0)
        prefs.unregisterOnSharedPreferenceChangeListener(this)
        super.onDestroy()
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        if (key == PrefConstants.THEME) {
            UIUtils.restartActivity(this)
        }
    }
}