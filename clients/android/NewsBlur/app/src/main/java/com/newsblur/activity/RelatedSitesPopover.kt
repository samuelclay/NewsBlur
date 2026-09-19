package com.newsblur.activity

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.view.View
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.platform.createLifecycleAwareWindowRecomposer
import androidx.compose.ui.platform.findViewTreeCompositionContext
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.discover.DiscoveryViewModel
import com.newsblur.discover.RelatedDiscoveryContent
import com.newsblur.R
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.AnchoredPopover
import com.newsblur.util.FeedSet
import com.newsblur.util.ImageLoader
import com.newsblur.util.TryFeedStore
import com.newsblur.util.UIUtils
import com.newsblur.viewModel.DiscoverFeedsViewModel
import kotlinx.coroutines.launch

/** RelatedSitesPopover.kt reuses discovery data and actions while keeping the floating source button visible. */
object RelatedSitesPopover {
    @JvmStatic fun show(
        activity: ItemsList,
        anchor: View,
        feedSet: FeedSet,
        loader: ImageLoader,
        thumbnailLoader: ImageLoader,
        tryStore: TryFeedStore,
    ): PopupWindow {
        val theme = activity.prefsRepo.getResolvedTheme(activity)
        val sheetColors = ReaderSheetPalette.colors(theme)
        fun dp(value: Int) = UIUtils.dp2px(activity, value)
        val model = ViewModelProvider(activity)[DiscoverFeedsViewModel::class.java]
        val actions = ViewModelProvider(activity)[DiscoveryViewModel::class.java]
        val root =
            LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                background = GradientDrawable().apply {
                    cornerRadius = dp(18).toFloat()
                    setColor(sheetColors.background.toArgb())
                    setStroke(dp(1), sheetColors.border.toArgb())
                }
                clipToOutline = true
            }
        val header =
            LinearLayout(activity).apply {
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(16), dp(4), dp(8), dp(4))
            }
        header.addView(
            TextView(activity).apply {
                text = activity.getString(R.string.discover_related_sites_title)
                textSize = 17f
                gravity = Gravity.CENTER_VERTICAL
                setTextColor(sheetColors.textPrimary.toArgb())
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            },
            LinearLayout.LayoutParams(0, dp(48), 1f),
        )
        val toggle =
            ImageButton(activity).apply {
                setPadding(dp(12), dp(12), dp(12), dp(12))
                imageTintList = ColorStateList.valueOf(sheetColors.textPrimary.toArgb())
                background = RippleDrawable(
                    ColorStateList.valueOf(ReaderSheetPalette.menuRowHighlightArgb(theme)),
                    null,
                    GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        setColor(Color.WHITE)
                    },
                )
            }
        header.addView(toggle, LinearLayout.LayoutParams(dp(48), dp(48)))
        root.addView(header)
        root.addView(View(activity).apply {
            setBackgroundColor(sheetColors.border.toArgb())
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1)).apply {
            setMargins(dp(14), 0, dp(14), dp(4))
        })
        // RelatedSitesPopover.kt supplies a parent explicitly: PopupDecorView has no lifecycle owner.
        val hostComposition = anchor.findViewTreeCompositionContext()
        val popupRecomposer = if (hostComposition == null) root.createLifecycleAwareWindowRecomposer(lifecycle = activity.lifecycle) else null
        val content = ComposeView(activity).apply {
            setViewTreeLifecycleOwner(activity)
            setViewTreeSavedStateRegistryOwner(activity)
            setParentCompositionContext(hostComposition ?: popupRecomposer)
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindowOrReleasedFromPool)
            setContent {
                NewsBlurTheme(variant = activity.prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                    RelatedDiscoveryContent(activity, model, actions, loader, thumbnailLoader, tryStore)
                }
            }
        }
        root.addView(content, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        val popup = PopupWindow(root, dp(360), dp(520), true)
        toggle.setOnClickListener { actions.toggleGrid() }
        if (feedSet.isSingleNormal) {
            val feed = (activity as NbActivity).dbHelper.getFeed(feedSet.singleFeed)
            if (feed != null) model.load(feed) else model.load(feedSet.singleFeed)
        } else {
            model.load(feedSet.allFeeds)
        }
        val job =
            activity.lifecycleScope.launch {
                actions.state.collect { state ->
                    toggle.setImageResource(if (state.grid) R.drawable.ic_discover_view_list else R.drawable.ic_discover_view_grid)
                    toggle.contentDescription = activity.getString(if (state.grid) R.string.discover_show_list else R.string.discover_show_grid)
                }
            }
        popup.setOnDismissListener {
            job.cancel()
            content.disposeComposition()
            popupRecomposer?.cancel()
        }
        popup.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popup.isOutsideTouchable = true
        popup.elevation = dp(12).toFloat()
        popup.inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
        try {
            AnchoredPopover.show(anchor, popup, popup.width, popup.height)
        } catch (error: RuntimeException) {
            job.cancel()
            content.disposeComposition()
            popupRecomposer?.cancel()
            throw error
        }
        return popup
    }
}
