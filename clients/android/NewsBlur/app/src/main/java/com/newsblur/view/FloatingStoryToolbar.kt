package com.newsblur.view

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.RelativeLayout
import android.widget.Space
import androidx.core.graphics.ColorUtils
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.databinding.ActivityItemslistBinding
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.FloatingToolbarLayout
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils

/** FloatingStoryToolbar.kt leaves the original XML top toolbar untouched when the preference is Top. */
class FloatingStoryToolbar(private val binding: ActivityItemslistBinding, private val theme: ThemeValue) {
    private val context = binding.root.context
    private val leading = LinearLayout(context).apply { gravity = Gravity.CENTER_VERTICAL }
    private val trailing = LinearLayout(context).apply { gravity = Gravity.CENTER_VERTICAL }
    private var merged = false
    private var lastFit: FloatingToolbarLayout.Fit? = null
    private fun dp(value: Int) = UIUtils.dp2px(context, value)

    init {
        val header = binding.itemlistStoryHeader
        header.layoutTransition = null
        (header.layoutParams as RelativeLayout.LayoutParams).apply {
            removeRule(RelativeLayout.ALIGN_PARENT_TOP)
            addRule(RelativeLayout.ALIGN_PARENT_BOTTOM)
            bottomMargin = dp(8)
        }
        (binding.itemlistTryFeedBanner.layoutParams as RelativeLayout.LayoutParams).apply {
            removeRule(RelativeLayout.BELOW)
            addRule(RelativeLayout.ALIGN_PARENT_TOP)
        }
        (binding.activityItemlistContainer.layoutParams as RelativeLayout.LayoutParams).addRule(RelativeLayout.ABOVE, header.id)
        header.removeView(binding.itemlistSearchContainer)
        header.addView(binding.itemlistSearchContainer, 0)
        val bar = binding.itemlistStoryHeaderBar
        bar.removeAllViews()
        bar.setPadding(dp(16), dp(4), dp(16), dp(4))
        bar.clipChildren = false
        bar.clipToPadding = false
        header.clipChildren = false
        header.clipToPadding = false
        listOf(binding.itemlistDiscoverPill, binding.itemlistOptionsPill, binding.itemlistSearchPill).forEachIndexed { index, button ->
            button.layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(44)).apply { if (index > 0) marginStart = dp(6) }
            button.minimumWidth = dp(44)
            button.minWidth = dp(44)
            button.maxWidth = Int.MAX_VALUE
            button.setPaddingRelative(dp(12), 0, dp(12), 0)
            button.iconSize = dp(14)
            button.iconPadding = dp(4)
            button.cornerRadius = dp(22)
            button.strokeWidth = 0
            leading.addView(button)
        }
        binding.itemlistMarkReadContainer.layoutParams = LinearLayout.LayoutParams(dp(79), dp(44))
        binding.itemlistMarkReadMoreButton.layoutParams.width = dp(26)
        binding.itemlistMarkReadButton.layoutParams.width = dp(52)
        binding.itemlistMarkReadMoreButton.contentDescription = context.getString(R.string.story_header_mark_read_cutoff)
        trailing.addView(binding.itemlistMarkReadContainer)
        bar.addView(leading, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(44)))
        bar.addView(Space(context), LinearLayout.LayoutParams(0, 1, 1f))
        bar.addView(trailing, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(44)))
        binding.itemlistSearchContainer.setPadding(dp(16), dp(4), dp(16), dp(4))
        val searchField = binding.itemlistSearchQuery.parent as View
        searchField.layoutParams.height = dp(44)
        searchField.background = capsule(theme)
        applyTheme(false)
        header.requestLayout()
    }

    fun update(fullOptions: String, compactOptions: String, searchActive: Boolean) {
        val bar = binding.itemlistStoryHeaderBar
        if (bar.width <= 0) return
        val discover = binding.itemlistDiscoverPill
        val options = binding.itemlistOptionsPill
        val search = binding.itemlistSearchPill
        val showDiscover = discover.visibility == View.VISIBLE
        val showSearch = search.visibility == View.VISIBLE
        val showMark = binding.itemlistMarkReadContainer.visibility == View.VISIBLE
        trailing.visibility = if (showMark) View.VISIBLE else View.GONE
        val width = UIUtils.px2dp(context, bar.width - dp(32)).toInt()
        fun widthOf(button: MaterialButton, text: String) =
            UIUtils.px2dp(context, (button.paint.measureText(text) + dp(24 + 14 + 4)).toInt()).toInt().coerceAtLeast(44)
        val discoverTitle = context.getString(R.string.story_header_related_sites)
        val searchTitle = context.getString(R.string.story_header_search)
        val fit = FloatingToolbarLayout.fit(width, widthOf(options, fullOptions), widthOf(options, compactOptions),
            widthOf(discover, discoverTitle), widthOf(search, searchTitle), showDiscover, showSearch, showMark)
        if (fit != lastFit || options.contentDescription != fullOptions) {
            lastFit = fit
            merged = fit.merged
            options.text = when (fit.options) { 2 -> fullOptions; 1 -> compactOptions; else -> "" }
            options.contentDescription = fullOptions
            discover.text = if (fit.discoverText) discoverTitle else ""
            search.text = if (fit.searchText) searchTitle else ""
            // FloatingStoryToolbar.kt hides gaps for absent controls and keeps mark-read at the trailing edge.
            var first = true
            listOf(discover, options, search).forEach { button ->
                (button.layoutParams as LinearLayout.LayoutParams).apply {
                    marginStart = if (!first && button.visibility == View.VISIBLE) dp(6) else 0
                    if (button.visibility == View.VISIBLE) first = false
                }
            }
            applyTheme(searchActive)
            bar.requestLayout()
        } else {
            styleButtons(searchActive)
        }
    }

    fun applyTheme(searchActive: Boolean) {
        binding.itemlistStoryHeader.setBackgroundColor(Color.TRANSPARENT)
        binding.itemlistSearchContainer.setBackgroundColor(Color.TRANSPARENT)
        val bar = binding.itemlistStoryHeaderBar
        // FloatingStoryToolbar.kt paints only the capsules, preserving the clear gap between groups.
        bar.background = if (merged) capsule(theme) else null
        bar.elevation = if (merged) dp(6).toFloat() else 0f
        listOf(leading, trailing).forEach {
            it.background = if (merged) null else capsule(theme)
            it.elevation = if (merged) 0f else dp(6).toFloat()
            it.setPadding(dp(4), 0, dp(4), 0)
        }
        styleButtons(searchActive)
    }

    private fun styleButtons(searchActive: Boolean) {
        val color = ReaderSheetPalette.textPrimaryArgb(theme)
        listOf(binding.itemlistDiscoverPill, binding.itemlistOptionsPill, binding.itemlistSearchPill).forEach {
            it.strokeWidth = 0
            it.cornerRadius = dp(22)
            it.setTextColor(color)
            it.iconTint = ColorStateList.valueOf(color)
            it.backgroundTintList = ColorStateList.valueOf(if (it === binding.itemlistSearchPill && searchActive) ColorUtils.setAlphaComponent(ReaderSheetPalette.accentArgb(theme), 55) else Color.TRANSPARENT)
        }
        binding.itemlistMarkReadContainer.background = null
        binding.itemlistMarkReadDivider.setBackgroundColor(ReaderSheetPalette.borderArgb(theme))
        binding.itemlistMarkReadMoreButton.setColorFilter(color)
        binding.itemlistMarkReadButton.setColorFilter(color)
    }

    private fun capsule(theme: ThemeValue) = FloatingToolbarSurface.background(context, theme)
}

object FloatingToolbarSurface {
    @JvmStatic fun background(context: android.content.Context, theme: ThemeValue) = GradientDrawable().apply {
        cornerRadius = UIUtils.dp2px(context, 26).toFloat()
        setColor(ColorUtils.setAlphaComponent(ReaderSheetPalette.backgroundArgb(theme), 245))
        setStroke(UIUtils.dp2px(context, 1), ReaderSheetPalette.borderArgb(theme))
    }
}
