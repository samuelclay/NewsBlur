package com.newsblur.delegate

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.databinding.ViewMainMenuRowBinding
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.AnchoredPopover
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.PopupMenuTextScaler
import com.newsblur.util.UIUtils

/** ActionMenuPopover.kt presents the shared feed and story actions without replacing their scope or callbacks. */
object ActionMenuPopover {
    @JvmStatic fun show(
        activity: NbActivity,
        anchor: View,
        menu: Menu,
        theme: ThemeValue,
        selected: MenuItem.OnMenuItemClickListener,
    ): PopupWindow {
        fun dp(value: Int) = UIUtils.dp2px(activity, value)
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
        val width = PopupMenuTextScaler.scaledWidthPx(dp(304), activity.prefsRepo.getListTextSize())
        val popup = PopupWindow(scroll, width, LinearLayout.LayoutParams.WRAP_CONTENT, true)
        fun render(current: Menu, heading: CharSequence? = null) {
            rows.removeAllViews()
            scroll.scrollTo(0, 0)
            if (heading != null) {
                val back = ViewMainMenuRowBinding.inflate(LayoutInflater.from(activity), rows, false)
                back.root.minimumHeight = dp(48)
                back.textMenuTitle.text = heading
                back.textMenuTitle.setTextColor(ReaderSheetPalette.textPrimaryArgb(theme))
                back.textMenuTitle.setSingleLine(false)
                back.iconMenu.setImageResource(R.drawable.ic_arrow_back)
                back.iconMenu.imageTintList = ColorStateList.valueOf(ReaderSheetPalette.textSecondaryArgb(theme))
                back.root.contentDescription = activity.getString(R.string.feed_menu_back_to_actions)
                back.root.setOnClickListener { render(menu) }
                rows.addView(back.root)
            }
            var previousGroup: Int? = null
            for (index in 0 until current.size()) {
                val item = current.getItem(index)
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
                row.iconAccessory.visibility = if (item.hasSubMenu() || item.isChecked) View.VISIBLE else View.GONE
                row.iconAccessory.setImageResource(if (item.isChecked) R.drawable.ic_read_check else R.drawable.ic_arrow_forward)
                row.iconAccessory.imageTintList = ColorStateList.valueOf(ReaderSheetPalette.accentArgb(theme))
                row.root.isSelected = item.isChecked
                row.root.setOnClickListener {
                    val submenu = item.subMenu
                    if (submenu != null) {
                        render(submenu, item.title)
                    } else {
                        popup.dismiss()
                        selected.onMenuItemClick(item)
                    }
                }
                rows.addView(row.root)
            }
            PopupMenuTextScaler.apply(rows, activity.prefsRepo.getListTextSize())
            if (popup.isShowing) {
                scroll.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
                AnchoredPopover.show(anchor, popup, width, scroll.measuredHeight, true)
            }
        }
        render(menu)
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
        scroll.addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(view: View) = Unit
            override fun onViewDetachedFromWindow(view: View) { anchor.removeOnAttachStateChangeListener(detachListener) }
        })
        return popup
    }
}
