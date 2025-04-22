package com.newsblur.util

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.util.TypedValue
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.viewbinding.ViewBinding
import com.google.android.material.appbar.MaterialToolbar
import com.newsblur.R
import com.newsblur.util.PrefConstants.ThemeValue

object EdgeToEdgeUtil {

    fun Activity.applyTheme() {
        val value = PrefsUtils.getSelectedTheme(this)

        val themeRes: Int = when (value) {
            ThemeValue.LIGHT -> R.style.NewsBlurTheme
            ThemeValue.DARK -> R.style.NewsBlurDarkTheme
            ThemeValue.BLACK -> R.style.NewsBlurBlackTheme
            ThemeValue.AUTO -> {
                val nightModeFlags = (this.resources.configuration.uiMode
                        and Configuration.UI_MODE_NIGHT_MASK)
                if (nightModeFlags == Configuration.UI_MODE_NIGHT_YES)
                    R.style.NewsBlurDarkTheme
                else
                    R.style.NewsBlurTheme
            }
        }

        this.setTheme(themeRes)

        // system bar
        val window = this.window
        val isLightIcons = shouldUseLightIcons(this, value)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        } else {
            WindowCompat.setDecorFitsSystemWindows(window, true)
        }

        val statusBarColor = getThemeColor(this, android.R.attr.statusBarColor)
        val navBarColor = getThemeColor(this, android.R.attr.navigationBarColor)

        window.statusBarColor = statusBarColor
        window.navigationBarColor = navBarColor

        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = isLightIcons
            isAppearanceLightNavigationBars = isLightIcons
        }
    }

    @JvmStatic
    fun Activity.applyView(binding: ViewBinding) {
        setContentView(binding.root)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
                val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars())
                val navBar = insets.getInsets(WindowInsetsCompat.Type.navigationBars())

                findViewById<View>(R.id.toolbar)?.let { toolbar ->
                    toolbar.setPadding(
                            toolbar.paddingLeft,
                            statusBar.top,
                            toolbar.paddingRight,
                            toolbar.paddingBottom
                    )
                }

                findViewById<View>(R.id.container)?.let {
                    it.setPadding(
                            it.paddingLeft,
                            it.paddingTop,
                            it.paddingRight,
                            navBar.bottom,
                    )
                }

                WindowInsetsCompat.CONSUMED
            }
        }
    }

    private fun getThemeColor(context: Context, attr: Int): Int {
        val typedValue = TypedValue()
        context.theme.resolveAttribute(attr, typedValue, true)
        return typedValue.data
    }

    private fun shouldUseLightIcons(context: Context, theme: ThemeValue): Boolean {
        return when (theme) {
            ThemeValue.LIGHT -> true
            ThemeValue.DARK, ThemeValue.BLACK -> false
            ThemeValue.AUTO -> {
                val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                nightMode != Configuration.UI_MODE_NIGHT_YES
            }
        }
    }
}