package com.newsblur.delegate

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import com.newsblur.R
import com.newsblur.activity.ItemsList
import com.newsblur.databinding.ViewMainMenuRowBinding
import com.newsblur.design.ReaderSheetPalette
import com.newsblur.util.AnchoredPopover
import com.newsblur.util.UIUtils
import com.newsblur.view.FloatingToolbarSurface
import java.util.function.IntConsumer

object MarkReadCutoffPopover {
    @JvmStatic fun show(activity: ItemsList, anchor: View, days: IntArray, selected: IntConsumer): PopupWindow {
        val theme = activity.prefsRepo.getResolvedTheme(activity)
        val rows = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, UIUtils.dp2px(activity, 8), 0, UIUtils.dp2px(activity, 8))
            background = FloatingToolbarSurface.background(activity, theme)
        }
        val scroll = ScrollView(activity).apply { addView(rows); isFillViewport = false }
        val popup = PopupWindow(scroll, UIUtils.dp2px(activity, 304), LinearLayout.LayoutParams.WRAP_CONTENT, true)
        days.forEach { day ->
            val row = ViewMainMenuRowBinding.inflate(LayoutInflater.from(activity), rows, false)
            row.textMenuTitle.text = activity.resources.getQuantityString(R.plurals.story_header_mark_read_older_than_days, day, day)
            row.textMenuTitle.setTextColor(ReaderSheetPalette.textPrimaryArgb(theme))
            row.iconMenu.setImageResource(R.drawable.ic_mark_read)
            row.iconMenu.imageTintList = ColorStateList.valueOf(ReaderSheetPalette.textPrimaryArgb(theme))
            row.root.minimumHeight = UIUtils.dp2px(activity, 44)
            row.root.setOnClickListener { popup.dismiss(); selected.accept(day) }
            rows.addView(row.root)
        }
        popup.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popup.isOutsideTouchable = true
        popup.elevation = UIUtils.dp2px(activity, 10).toFloat()
        popup.inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
        scroll.measure(View.MeasureSpec.makeMeasureSpec(popup.width, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
        AnchoredPopover.show(anchor, popup, popup.width, scroll.measuredHeight)
        return popup
    }
}
