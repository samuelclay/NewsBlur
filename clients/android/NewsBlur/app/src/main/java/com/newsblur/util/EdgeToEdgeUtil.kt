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

        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
            val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars())
            val navBar = insets.getInsets(WindowInsetsCompat.Type.navigationBars())

            findViewById<View>(R.id.toolbar)?.updateTopPadding(statusBar.top)
            findViewById<View>(R.id.container)?.updateBottomPadding(navBar.bottom)

            WindowInsetsCompat.CONSUMED
        }
    }

    @JvmStatic
    fun Activity.applyViewMain(binding: ViewBinding) {
        setContentView(binding.root)

        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
            val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars())
            val navBar = insets.getInsets(WindowInsetsCompat.Type.navigationBars())

            findViewById<View>(R.id.toolbar)?.updateTopPadding(statusBar.top)
            findViewById<View>(R.id.bottom_toolbar)?.updateBottomPadding(navBar.bottom)

            WindowInsetsCompat.CONSUMED
        }
    }

    @JvmStatic
    fun Activity.applyViewReading(binding: ViewBinding) {
        setContentView(binding.root)

        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
            val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars())
            val navBar = insets.getInsets(WindowInsetsCompat.Type.navigationBars())

            findViewById<View>(R.id.toolbar)?.updateTopPadding(statusBar.top)
            findViewById<View>(R.id.overlay_container)?.updateBottomPadding(navBar.bottom)

            WindowInsetsCompat.CONSUMED
        }
    }

    fun View.applyNavBarInsetBottomTo(targetView: View) {
        navBarInsetBottom()?.let { bottom ->
            targetView.updateBottomPadding(bottom)
        }
    }

    private fun View.navBarInsetBottom(): Int? = ViewCompat.getRootWindowInsets(this)
            ?.getInsets(WindowInsetsCompat.Type.navigationBars())
            ?.bottom

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

    private fun View.updateTopPadding(top: Int) {
        setPadding(paddingLeft, top, paddingRight, paddingBottom)
    }

    private fun View.updateBottomPadding(bottom: Int) {
        setPadding(paddingLeft, paddingTop, paddingRight, bottom)
    }
}