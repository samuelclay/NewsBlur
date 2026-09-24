package com.newsblur.delegate

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import androidx.core.content.ContextCompat
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.util.ListTextSize
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils

/** ListMenuSegments.kt shares the inline appearance controls across feed and story-list popovers. */
object ListMenuSegments {
    val fontSizes = linkedMapOf(
        R.id.menu_text_size_xs to ListTextSize.XS,
        R.id.menu_text_size_s to ListTextSize.S,
        R.id.menu_text_size_m to ListTextSize.M,
        R.id.menu_text_size_l to ListTextSize.L,
        R.id.menu_text_size_xl to ListTextSize.XL,
    )
    val themes = linkedMapOf(
        R.id.menu_theme_auto to ThemeValue.AUTO,
        R.id.menu_theme_light to ThemeValue.LIGHT,
        R.id.menu_theme_sepia to ThemeValue.SEPIA,
        R.id.menu_theme_dark to ThemeValue.DARK,
        R.id.menu_theme_black to ThemeValue.BLACK,
    )

    fun fontSize(activity: NbActivity, selected: (Int) -> Unit): LinearLayout =
        create(activity, fontSizes.map { (id, size) -> Option(id, size.name) },
            fontSizes.entries.firstOrNull { it.value.size == activity.prefsRepo.getListTextSize() }?.key,
            activity.getString(R.string.story_title_list_font_size), selected)

    fun theme(activity: NbActivity, selected: (Int) -> Unit): LinearLayout =
        create(activity, listOf(
            Option(R.id.menu_theme_auto, activity.getString(R.string.auto)),
            Option(R.id.menu_theme_light, activity.getString(R.string.light), R.drawable.ic_theme_dot_light),
            Option(R.id.menu_theme_sepia, activity.getString(R.string.sepia), R.drawable.ic_theme_dot_sepia),
            Option(R.id.menu_theme_dark, activity.getString(R.string.dark), R.drawable.ic_theme_dot_dark),
            Option(R.id.menu_theme_black, activity.getString(R.string.black), R.drawable.ic_theme_dot_black),
        ), themes.entries.first { it.value == activity.prefsRepo.getSelectedTheme() }.key,
            activity.getString(R.string.menu_theme_choose), selected)

    private data class Option(val id: Int, val label: String, val icon: Int? = null)

    private fun create(
        activity: NbActivity,
        options: List<Option>,
        checkedId: Int?,
        description: String,
        selected: (Int) -> Unit,
    ): LinearLayout {
        fun dp(value: Int) = UIUtils.dp2px(activity, value)
        val colors = when (activity.prefsRepo.getResolvedTheme(activity)) {
            ThemeValue.DARK -> intArrayOf(R.color.segmented_control_background_dark, R.color.segmented_control_selected_dark, R.color.segmented_control_text_dark, R.color.segmented_control_selected_text_dark)
            ThemeValue.BLACK -> intArrayOf(R.color.segmented_control_background_black, R.color.segmented_control_selected_black, R.color.segmented_control_text_black, R.color.segmented_control_selected_text_black)
            ThemeValue.SEPIA -> intArrayOf(R.color.segmented_control_background_sepia, R.color.segmented_control_selected_sepia, R.color.segmented_control_text_sepia, R.color.segmented_control_selected_text_sepia)
            else -> intArrayOf(R.color.segmented_control_background_light, R.color.segmented_control_selected_light, R.color.segmented_control_text_light, R.color.segmented_control_selected_text_light)
        }.map { ContextCompat.getColor(activity, it) }
        val states = arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf())
        val group = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            contentDescription = description
            setPadding(dp(2), dp(2), dp(2), dp(2))
            background = GradientDrawable().apply {
                cornerRadius = dp(24).toFloat()
                setColor(colors[0])
            }
        }
        val buttons = options.map { option ->
            MaterialButton(activity).apply {
                id = option.id
                layoutParams = LinearLayout.LayoutParams(0, dp(36), 1f)
                isCheckable = true
                isChecked = option.id == checkedId
                stateListAnimator = null
                elevation = 0f
                translationZ = 0f
                isAllCaps = false
                textSize = 13f
                text = if (option.icon == null) option.label else ""
                contentDescription = option.label
                tooltipText = option.label
                minWidth = 0
                minimumWidth = 0
                minHeight = 0
                minimumHeight = 0
                insetTop = 0
                insetBottom = 0
                setPadding(0, 0, 0, 0)
                cornerRadius = dp(22)
                strokeWidth = 0
                gravity = Gravity.CENTER
                textAlignment = View.TEXT_ALIGNMENT_CENTER
                backgroundTintList = ColorStateList(states, intArrayOf(colors[1], Color.TRANSPARENT))
                setTextColor(ColorStateList(states, intArrayOf(colors[3], colors[2])))
                option.icon?.let {
                    setIconResource(it)
                    iconTint = null
                    iconSize = dp(20)
                    iconPadding = 0
                    iconGravity = MaterialButton.ICON_GRAVITY_TEXT_TOP
                }
                group.addView(this)
            }
        }
        buttons.forEach { button ->
            button.setOnClickListener {
                buttons.forEach { it.isChecked = it === button }
                selected(button.id)
            }
        }
        return group
    }
}
