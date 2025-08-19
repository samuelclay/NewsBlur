package com.newsblur.util

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.util.TypedValue
import android.view.View
import android.view.ViewGroup
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updateLayoutParams
import androidx.viewbinding.ViewBinding
import com.newsblur.R
import com.newsblur.util.PrefConstants.ThemeValue

object EdgeToEdgeUtil {

    fun Activity.applyTheme(theme: ThemeValue) {
        val themeRes: Int = when (theme) {
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
        val isLightIcons = shouldUseLightIcons(this, theme)

        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = isLightIcons
            isAppearanceLightNavigationBars = isLightIcons
        }
    }

    /**
     * Sets up edge-to-edge views on the called activity.
     * Notice the setContentView method which sets the view.
     * All of the activities call this method, hence the multiple
     * findViewById calls that handle all use cases.
     */
    @JvmStatic
    fun Activity.applyView(binding: ViewBinding) {
        setContentView(binding.root)

        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
            val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars())
            val navBar = insets.getInsets(WindowInsetsCompat.Type.navigationBars())

            // AppBarLayout or Toolbar
            findViewById<View>(R.id.app_bar_layout)?.applyToolbarInsets(statusBar, navBar)
                    ?: findViewById<View>(R.id.toolbar)?.applyToolbarInsets(statusBar, navBar)

            // Container or Content
            findViewById<View>(R.id.container)?.applyContentInsets(navBar)
                    ?: findViewById<View>(R.id.content)?.applyContentInsets(navBar)

            // Reading - activity_reading.xml
            findViewById<View>(R.id.content_bottom_overlay)?.let {
                it.setPadding(it.paddingLeft, it.paddingTop, it.paddingRight, navBar.bottom)
            }

            // Main - activity_main.xml
            findViewById<View>(R.id.bottom_toolbar)?.applyBottomToolbarInsets(navBar)

            // sets the background on the navigation bar in landscape mode
            if (navBar.left > 0 || navBar.right > 0) {
                val tv = TypedValue()
                binding.root.context.theme.resolveAttribute(android.R.attr.navigationBarColor, tv, true)
                binding.root.setBackgroundColor(tv.data)
            } else {
                binding.root.setBackgroundColor(0)
            }

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

    private fun View.updateBottomPadding(bottom: Int) {
        setPadding(paddingLeft, paddingTop, paddingRight, bottom)
    }

    private fun View.applyContentInsets(navBar: Insets) {
        if (navBar.left > 0 || navBar.right > 0) {
            updateLayoutParams<ViewGroup.MarginLayoutParams> {
                leftMargin = navBar.left
                rightMargin = navBar.right
            }
        }
    }

    private fun View.applyToolbarInsets(statusBar: Insets, navBar: Insets) {
        if (navBar.left > 0 || navBar.right > 0) {
            updateLayoutParams<ViewGroup.MarginLayoutParams> {
                leftMargin = navBar.left
                rightMargin = navBar.right
            }
        }
        setPadding(paddingLeft, statusBar.top, paddingRight, paddingBottom)
    }

    private fun View.applyBottomToolbarInsets(navBar: Insets) {
        if (navBar.left > 0 || navBar.right > 0) {
            updateLayoutParams<ViewGroup.MarginLayoutParams> {
                leftMargin = navBar.left
                rightMargin = navBar.right
            }
        } else {
            setPadding(paddingLeft, paddingTop, paddingRight, navBar.bottom)
        }
    }
}