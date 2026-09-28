package com.newsblur.util

import android.app.Activity
import android.content.Context
import android.content.res.Configuration
import android.provider.Settings
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
    internal data class HorizontalMargins(
        val left: Int,
        val right: Int,
    )

    internal fun updatedHorizontalMargins(
        currentLeft: Int,
        currentRight: Int,
        navBarLeft: Int,
        navBarRight: Int,
    ): HorizontalMargins {
        val currentMargins = HorizontalMargins(currentLeft, currentRight)
        val targetMargins = HorizontalMargins(navBarLeft, navBarRight)
        return if (currentMargins == targetMargins) currentMargins else targetMargins
    }

    fun Activity.applyTheme(
        theme: ThemeValue,
        translucent: Boolean = false,
    ) {
        val themeRes: Int =
            when (theme) {
                ThemeValue.LIGHT -> if (translucent) R.style.NewsBlurTheme_Translucent else R.style.NewsBlurTheme
                ThemeValue.SEPIA -> if (translucent) R.style.NewsBlurSepiaTheme_Translucent else R.style.NewsBlurSepiaTheme
                ThemeValue.DARK -> if (translucent) R.style.NewsBlurDarkTheme_Translucent else R.style.NewsBlurDarkTheme
                ThemeValue.BLACK -> if (translucent) R.style.NewsBlurBlackTheme_Translucent else R.style.NewsBlurBlackTheme
                ThemeValue.AUTO -> {
                    val resolved = resolveAutoTheme(this)
                    when (resolved) {
                        ThemeValue.SEPIA -> if (translucent) R.style.NewsBlurSepiaTheme_Translucent else R.style.NewsBlurSepiaTheme
                        ThemeValue.BLACK -> if (translucent) R.style.NewsBlurBlackTheme_Translucent else R.style.NewsBlurBlackTheme
                        ThemeValue.DARK -> if (translucent) R.style.NewsBlurDarkTheme_Translucent else R.style.NewsBlurDarkTheme
                        else -> if (translucent) R.style.NewsBlurTheme_Translucent else R.style.NewsBlurTheme
                    }
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
        val collapsingReader = findViewById<View>(R.id.reading_back_swipe_edge) != null
        if (collapsingReader) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
            // UIUtils.restartActivity preserves the framework decor, including fitting parents that can
            // consume all insets before activity_reading.xml receives them. The reader owns these insets.
            var parent = binding.root.parent as? View
            while (parent != null && parent !== window.decorView) {
                if (parent.fitsSystemWindows) {
                    parent.fitsSystemWindows = false
                    parent.setPadding(0, 0, 0, 0)
                }
                parent = parent.parent as? View
            }
        }
        // Reading.kt needs themed paint behind the transparent status bar even before insets are redispatched.
        if (collapsingReader) binding.root.setBackgroundColor(resolveSystemBarColor(android.R.attr.navigationBarColor))

        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { _, insets ->
            val statusBar = insets.getInsets(WindowInsetsCompat.Type.statusBars())
            val navBar = insets.getInsets(WindowInsetsCompat.Type.navigationBars())

            // EdgeToEdgeUtil.kt keeps the status bar clear when the reader toolbar collapses.
            val toolbarStatusBar = if (collapsingReader) Insets.NONE else statusBar
            if (collapsingReader) binding.root.setPadding(0, statusBar.top, 0, 0)

            // AppBarLayout or Toolbar
            findViewById<View>(R.id.app_bar_layout)?.applyToolbarInsets(toolbarStatusBar, navBar)
                ?: findViewById<View>(R.id.toolbar)?.applyToolbarInsets(toolbarStatusBar, navBar)

            // Container or Content
            findViewById<View>(R.id.container)?.applyContentInsets(navBar)
                ?: findViewById<View>(R.id.content)?.applyContentInsets(navBar)

            // EdgeToEdgeUtil.kt keeps the floating story toolbar above navigation and the search keyboard.
            if (findViewById<View>(R.id.itemlist_story_header) != null) {
                findViewById<View>(R.id.content)?.let {
                    val keyboard = insets.getInsets(WindowInsetsCompat.Type.ime())
                    val bottomToolbar = getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)
                        .getString(PrefConstants.STORY_TOOLBAR_POSITION, "bottom") != "top"
                    val bottomInset = maxOf(navBar.bottom, keyboard.bottom)
                    // EdgeToEdgeUtil.kt insets only the floating controls so stories still draw behind them.
                    it.setPadding(it.paddingLeft, it.paddingTop, it.paddingRight, if (bottomToolbar) 0 else bottomInset)
                    if (bottomToolbar) {
                        findViewById<View>(R.id.itemlist_story_header)?.updateLayoutParams<ViewGroup.MarginLayoutParams> {
                            bottomMargin = bottomInset + UIUtils.dp2px(this@applyView, 8)
                        }
                        // EdgeToEdgeUtil.kt reserves both search rows when a landscape keyboard leaves no room for the feed title.
                        val compactSearch = keyboard.bottom > 0 &&
                            binding.root.height - keyboard.bottom - statusBar.top < UIUtils.dp2px(this, 168)
                        findViewById<View>(R.id.toolbar)?.visibility = if (compactSearch) View.GONE else View.VISIBLE
                        val verticalPadding = if (compactSearch) 0 else UIUtils.dp2px(this, 4)
                        listOf(R.id.itemlist_story_header_bar, R.id.itemlist_search_container).forEach { id ->
                            findViewById<View>(id)?.let { row ->
                                row.setPadding(row.paddingLeft, verticalPadding, row.paddingRight, verticalPadding)
                            }
                        }
                    }
                }
            }

            // Reading - activity_reading.xml
            findViewById<View>(R.id.content_bottom_overlay)?.let {
                it.applyHorizontalNavBarMargins(navBar)
                it.setPadding(it.paddingLeft, it.paddingTop, it.paddingRight, navBar.bottom)
            }

            // Main - activity_main.xml
            findViewById<View>(R.id.bottom_toolbar)?.applyBottomToolbarInsets(navBar)

            // sets the background on the navigation bar in landscape mode
            if (collapsingReader || navBar.left > 0 || navBar.right > 0) {
                binding.root.setBackgroundColor(resolveSystemBarColor(android.R.attr.navigationBarColor))
            } else {
                binding.root.setBackgroundColor(0)
            }

            WindowInsetsCompat.CONSUMED
        }
    }

    private fun Activity.resolveSystemBarColor(attribute: Int): Int {
        val value = TypedValue()
        theme.resolveAttribute(attribute, value, true)
        return value.data
    }

    fun View.applyNavBarInsetBottomTo(targetView: View) {
        navBarInsetBottom()?.let { bottom ->
            targetView.updateBottomPadding(bottom)
        }
    }

    private fun View.navBarInsetBottom(): Int? =
        ViewCompat
            .getRootWindowInsets(this)
            ?.getInsets(WindowInsetsCompat.Type.navigationBars())
            ?.bottom

    @JvmStatic
    fun isHighContrastTextEnabled(context: Context): Boolean =
        try {
            Settings.Secure.getInt(context.contentResolver, "high_text_contrast_enabled", 0) == 1
        } catch (_: Exception) {
            false
        }

    private fun resolveAutoTheme(context: Context): ThemeValue {
        val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)
        val nightFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return if (nightFlags == Configuration.UI_MODE_NIGHT_YES) {
            val name = prefs.getString(PrefConstants.THEME_DARK_VARIANT, ThemeValue.DARK.name)!!
            ThemeValue.valueOf(name)
        } else {
            val name = prefs.getString(PrefConstants.THEME_LIGHT_VARIANT, ThemeValue.LIGHT.name)!!
            ThemeValue.valueOf(name)
        }
    }

    private fun shouldUseLightIcons(
        context: Context,
        theme: ThemeValue,
    ): Boolean =
        when (theme) {
            ThemeValue.LIGHT, ThemeValue.SEPIA -> true
            ThemeValue.DARK, ThemeValue.BLACK -> false
            ThemeValue.AUTO -> {
                val resolved = resolveAutoTheme(context)
                resolved == ThemeValue.LIGHT || resolved == ThemeValue.SEPIA
            }
        }

    private fun View.updateBottomPadding(bottom: Int) {
        setPadding(paddingLeft, paddingTop, paddingRight, bottom)
    }

    private fun View.applyContentInsets(navBar: Insets) {
        applyHorizontalNavBarMargins(navBar)
    }

    private fun View.applyToolbarInsets(
        statusBar: Insets,
        navBar: Insets,
    ) {
        applyHorizontalNavBarMargins(navBar)
        setPadding(paddingLeft, statusBar.top, paddingRight, paddingBottom)
    }

    private fun View.applyBottomToolbarInsets(navBar: Insets) {
        updateLayoutParams<ViewGroup.MarginLayoutParams> {
            leftMargin = navBar.left + UIUtils.dp2px(context, 16)
            rightMargin = navBar.right + UIUtils.dp2px(context, 16)
            bottomMargin = navBar.bottom + UIUtils.dp2px(context, 8)
        }
    }

    private fun View.applyHorizontalNavBarMargins(navBar: Insets) {
        val currentMargins = layoutParams as? ViewGroup.MarginLayoutParams ?: return
        val margins =
            updatedHorizontalMargins(
                currentLeft = currentMargins.leftMargin,
                currentRight = currentMargins.rightMargin,
                navBarLeft = navBar.left,
                navBarRight = navBar.right,
            )
        if (currentMargins.leftMargin == margins.left && currentMargins.rightMargin == margins.right) {
            return
        }

        updateLayoutParams<ViewGroup.MarginLayoutParams> {
            leftMargin = margins.left
            rightMargin = margins.right
        }
    }
}
