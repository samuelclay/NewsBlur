package com.newsblur.delegate

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.MenuItem
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import androidx.appcompat.widget.PopupMenu
import com.newsblur.activity.NbActivity
import com.newsblur.databinding.ViewMainMenuRowBinding
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.domain.Story
import com.newsblur.util.AnchoredPopover
import com.newsblur.util.FeedSet
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.StoryOrder
import com.newsblur.util.UIUtils

/** StoryMenuPopover.kt presents the shared story actions without replacing their scope or callbacks. */
object StoryMenuPopover {
    fun show(
        activity: NbActivity,
        anchor: View,
        feedSet: FeedSet,
        story: Story,
        order: StoryOrder,
        theme: ThemeValue,
        selected: (MenuItem) -> Boolean,
    ): PopupWindow {
        fun dp(value: Int) = UIUtils.dp2px(activity, value)
        val menu = PopupMenu(activity, anchor)
        UIUtils.inflateStoryContextMenu(menu.menu, menu.menuInflater, feedSet, story, order)
        val rows = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(6), 0, dp(6))
        }
        val scroll = ScrollView(activity).apply {
            addView(rows)
            clipToOutline = true
            background = GradientDrawable().apply {
                cornerRadius = dp(18).toFloat()
                setColor(ReaderSheetPalette.backgroundArgb(theme))
                setStroke(dp(1), ReaderSheetPalette.borderArgb(theme))
            }
        }
        val popup = PopupWindow(scroll, dp(304), LinearLayout.LayoutParams.WRAP_CONTENT, true)
        var previousGroup: Int? = null
        for (index in 0 until menu.menu.size()) {
            val item = menu.menu.getItem(index)
            if (!item.isVisible) continue
            if (previousGroup != null && previousGroup != item.groupId) {
                rows.addView(View(activity).apply {
                    setBackgroundColor(ReaderSheetPalette.borderArgb(theme))
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1)).apply {
                        setMargins(dp(14), dp(5), dp(14), dp(5))
                    }
                    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                })
            }
            previousGroup = item.groupId
            val row = ViewMainMenuRowBinding.inflate(LayoutInflater.from(activity), rows, false)
            row.root.minimumHeight = dp(48)
            row.textMenuTitle.apply {
                text = item.title
                setSingleLine(false)
                ellipsize = null
                setTextColor(ReaderSheetPalette.textPrimaryArgb(theme))
            }
            row.iconMenu.apply {
                setImageDrawable(item.icon)
                imageTintList = ColorStateList.valueOf(ReaderSheetPalette.textSecondaryArgb(theme))
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }
            row.root.isEnabled = item.isEnabled
            row.root.setOnClickListener {
                popup.dismiss()
                selected(item)
            }
            rows.addView(row.root)
        }
        popup.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popup.isOutsideTouchable = true
        popup.elevation = dp(12).toFloat()
        popup.inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
        scroll.measure(
            View.MeasureSpec.makeMeasureSpec(popup.width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        AnchoredPopover.show(anchor, popup, popup.width, scroll.measuredHeight)
        val detachListener = object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(view: View) = Unit
            override fun onViewDetachedFromWindow(view: View) = popup.dismiss()
        }
        anchor.addOnAttachStateChangeListener(detachListener)
        popup.setOnDismissListener { anchor.removeOnAttachStateChangeListener(detachListener) }
        return popup
    }
}
