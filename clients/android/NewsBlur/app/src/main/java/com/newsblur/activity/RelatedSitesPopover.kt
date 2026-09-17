package com.newsblur.activity

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.domain.DiscoverFeedPayload
import com.newsblur.fragment.AddFeedFragment
import com.newsblur.util.AnchoredPopover
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedSet
import com.newsblur.util.ImageLoader
import com.newsblur.util.TryFeedStore
import com.newsblur.util.UIUtils
import com.newsblur.util.discoverThemePalette
import com.newsblur.view.FloatingToolbarSurface
import com.newsblur.viewModel.DiscoverFeedViewMode
import com.newsblur.viewModel.DiscoverFeedsViewModel
import kotlinx.coroutines.launch

/** RelatedSitesPopover.kt reuses discovery data and actions while keeping the floating source button visible. */
object RelatedSitesPopover {
    @JvmStatic fun show(activity: ItemsList, anchor: View, feedSet: FeedSet, loader: ImageLoader, tryStore: TryFeedStore): PopupWindow {
        val palette = discoverThemePalette(activity, activity.prefsRepo)
        val model = ViewModelProvider(activity)[DiscoverFeedsViewModel::class.java]
        val root = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            background = FloatingToolbarSurface.background(activity, activity.prefsRepo.getResolvedTheme(activity))
            clipToOutline = true
        }
        val header = LinearLayout(activity).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(UIUtils.dp2px(activity, 16), 0, UIUtils.dp2px(activity, 8), 0)
        }
        header.addView(TextView(activity).apply {
            text = activity.getString(R.string.discover_related_sites_title)
            textSize = 17f
            setTextColor(palette.textPrimaryColor)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }, LinearLayout.LayoutParams(0, UIUtils.dp2px(activity, 48), 1f))
        val toggle = MaterialButton(activity).apply { textSize = 12f; minWidth = 0; minimumWidth = 0; setTextColor(palette.textPrimaryColor); backgroundTintList = ColorStateList.valueOf(Color.TRANSPARENT) }
        header.addView(toggle)
        root.addView(header)
        val status = TextView(activity).apply { setTextColor(palette.textSecondaryColor); setPadding(24, 16, 24, 16) }
        root.addView(status)
        val recycler = RecyclerView(activity).apply { layoutManager = LinearLayoutManager(activity) }
        root.addView(recycler, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        val popup = PopupWindow(root, UIUtils.dp2px(activity, 360), UIUtils.dp2px(activity, 520), true)
        val adapter = DiscoverFeedAdapter(activity.layoutInflater, loader, palette, (activity as NbActivity).dbHelper.allFeeds, object : DiscoverFeedAdapter.Listener {
            override fun onTryFeed(payload: DiscoverFeedPayload) {
                popup.dismiss()
                val existing = (activity as NbActivity).dbHelper.getFeed(payload.feed.feedId)
                if (existing != null) {
                    FeedItemsList.startActivity(activity, FeedSet.singleFeed(existing.feedId), existing, AppConstants.ROOT_FOLDER, null, null)
                } else {
                    tryStore.set(payload.feed)
                    FeedItemsList.startTryFeedActivity(activity, payload.feed)
                }
            }
            override fun onAddFeed(payload: DiscoverFeedPayload) {
                popup.dismiss()
                AddFeedFragment.newInstance(payload.feed.address.ifBlank { payload.feed.feedLink }, payload.feed.title)
                    .show(activity.supportFragmentManager, "add_related_site")
            }
        })
        recycler.adapter = adapter
        recycler.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrolled(view: RecyclerView, dx: Int, dy: Int) {
                if (dy > 0 && (view.layoutManager as LinearLayoutManager).findLastVisibleItemPosition() >= adapter.itemCount - 3) model.loadNextPage()
            }
        })
        toggle.setOnClickListener { model.setViewMode(if (model.uiState.value.viewMode == DiscoverFeedViewMode.GRID) DiscoverFeedViewMode.LIST else DiscoverFeedViewMode.GRID) }
        if (feedSet.isSingleNormal) {
            val feed = (activity as NbActivity).dbHelper.getFeed(feedSet.singleFeed)
            if (feed != null) model.load(feed) else model.load(feedSet.singleFeed)
        } else model.load(feedSet.allFeeds)
        val job = activity.lifecycleScope.launch {
            model.uiState.collect { state ->
                adapter.submit(state.feeds, state.viewMode, palette, (activity as NbActivity).dbHelper.allFeeds)
                toggle.text = if (state.viewMode == DiscoverFeedViewMode.GRID) "List" else "Grid"
                status.visibility = if (state.feeds.isEmpty()) View.VISIBLE else View.GONE
                status.text = if (state.isLoadingInitial) activity.getString(R.string.loading) else state.errorMessage ?: activity.getString(R.string.discover_no_related_sites)
            }
        }
        popup.setOnDismissListener { job.cancel() }
        popup.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popup.isOutsideTouchable = true
        popup.elevation = UIUtils.dp2px(activity, 10).toFloat()
        popup.inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
        AnchoredPopover.show(anchor, popup, popup.width, popup.height)
        return popup
    }
}
