package com.newsblur.activity

import android.content.SharedPreferences
import android.os.Bundle
import android.view.MotionEvent
import androidx.appcompat.app.AppCompatActivity
import com.newsblur.R
import com.newsblur.databinding.ActivitySettingsBinding
import com.newsblur.fragment.SettingsFragment
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.EdgeToEdgeUtil.applyTheme
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.PrefConstants
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.ThemeAppearance
import com.newsblur.util.UIUtils
import com.newsblur.view.ThemeSwipeGesture
import com.newsblur.view.ThemeTransition
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class Settings :
    AppCompatActivity(),
    SharedPreferences.OnSharedPreferenceChangeListener {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    private var shownTheme: Pair<ThemeValue, ThemeValue>? = null
    private var themeTransitionToken: String? = null
    private val themeSwipe by lazy { ThemeSwipeGesture(this, prefsRepo) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyTheme(prefsRepo.getSelectedTheme())
        val binding = ActivitySettingsBinding.inflate(layoutInflater)
        applyView(binding)

        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.settings), true)

        // Settings.kt leaves the restored fragment and its Compose saved state intact after rotation.
        if (savedInstanceState == null) {
            supportFragmentManager
                .beginTransaction()
                .replace(binding.container.id, SettingsFragment())
                .commit()
        }

        themeTransitionToken = savedInstanceState?.getString(THEME_TRANSITION_TOKEN)
        shownTheme = shownTheme()
        val prefs = getSharedPreferences(PrefConstants.PREFERENCES, 0)
        prefs.registerOnSharedPreferenceChangeListener(this)
    }

    override fun onPostCreate(savedInstanceState: Bundle?) {
        super.onPostCreate(savedInstanceState)
        // Settings.kt fades from the old theme like NbActivity.kt's screens do.
        if (ThemeTransition.reveal(this, themeTransitionToken) { true }) themeTransitionToken = null
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString(THEME_TRANSITION_TOKEN, themeTransitionToken)
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        val prefs = getSharedPreferences(PrefConstants.PREFERENCES, 0)
        prefs.unregisterOnSharedPreferenceChangeListener(this)
        super.onDestroy()
    }

    // Settings.kt lets two fingers switch the theme, as iOS's Preferences does (ThemeSwipeGesture.kt).
    override fun dispatchTouchEvent(event: MotionEvent): Boolean = themeSwipe.dispatch(event) { super.dispatchTouchEvent(it) }

    private fun shownTheme() = prefsRepo.getSelectedTheme() to prefsRepo.getResolvedTheme(this)

    override fun onSharedPreferenceChanged(
        sharedPreferences: SharedPreferences?,
        key: String?,
    ) {
        // Settings.kt also re-themes when an appearance row changes Auto's colors without changing the theme.
        if (key in ThemeAppearance.preferenceKeys && shownTheme() != shownTheme) {
            shownTheme = shownTheme()
            themeTransitionToken = ThemeTransition.capture(this)
            UIUtils.restartActivity(this)
        }
    }

    private companion object {
        const val THEME_TRANSITION_TOKEN = "themeTransitionToken"
    }
}
