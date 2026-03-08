package com.newsblur.delegate

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.LayoutInflater
import android.view.Menu
import android.view.SubMenu
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import androidx.core.content.ContextCompat
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.newsblur.R
import com.newsblur.databinding.PopupReadingMenuBinding
import com.newsblur.databinding.ViewMainMenuRowBinding
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import kotlin.math.min

class ReadingStoryMenuPopup(
    private val context: Context,
    private val prefsRepo: PrefsRepo,
    private val controller: Controller,
) {
    interface Controller {
        fun buildMenuModel(): Menu

        fun onMenuItemSelected(itemId: Int): Boolean
    }

    fun show(anchor: View): PopupWindow {
        val binding = PopupReadingMenuBinding.inflate(LayoutInflater.from(context))
        val popupWindow =
            PopupWindow(
                binding.root,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                true,
            )

        val palette = popupPalette()
        val popupBackground = ContextCompat.getColor(context, palette.backgroundColor)
        val popupStroke = ContextCompat.getColor(context, palette.strokeColor)
        val dividerColor = ContextCompat.getColor(context, palette.dividerColor)
        val textColor = ContextCompat.getColor(context, palette.textColor)
        val accessoryColor = ContextCompat.getColor(context, palette.accessoryColor)

        binding.cardMenu.setCardBackgroundColor(popupBackground)
        binding.cardMenu.strokeColor = popupStroke
        binding.dividerFont.setBackgroundColor(dividerColor)
        binding.dividerToggles.setBackgroundColor(dividerColor)

        configureActionRows(binding, controller.buildMenuModel(), popupWindow, dividerColor, textColor, accessoryColor)
        configureFontRow(binding, controller.buildMenuModel(), popupWindow, textColor, accessoryColor)
        configureToggles(binding, popupWindow, palette)

        popupWindow.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popupWindow.isOutsideTouchable = true
        popupWindow.isTouchable = true
        popupWindow.inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
        popupWindow.elevation = UIUtils.dp2px(context, 16f)

        binding.root.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )

        val popupWidth = binding.root.measuredWidth
        val displayFrame = Rect()
        anchor.getWindowVisibleDisplayFrame(displayFrame)
        val location = IntArray(2)
        anchor.getLocationInWindow(location)
        val margin = UIUtils.dp2px(context, 8)
        val availableHeight = displayFrame.height() - margin * 2
        popupWindow.height = min(binding.root.measuredHeight, availableHeight)
        val popupHeight = popupWindow.height

        val x =
            (location[0] + anchor.width - popupWidth + UIUtils.dp2px(context, 4))
                .coerceIn(displayFrame.left + margin, displayFrame.right - popupWidth - margin)
        val preferredBelow = location[1] + anchor.height - UIUtils.dp2px(context, 4)
        val preferredAbove = location[1] - popupHeight + UIUtils.dp2px(context, 4)
        val y =
            if (preferredBelow + popupHeight <= displayFrame.bottom - margin) {
                preferredBelow
            } else {
                preferredAbove.coerceAtLeast(displayFrame.top + margin)
            }

        popupWindow.showAtLocation(anchor.rootView, Gravity.NO_GRAVITY, x, y)
        return popupWindow
    }

    private fun configureActionRows(
        binding: PopupReadingMenuBinding,
        menu: Menu,
        popupWindow: PopupWindow,
        dividerColor: Int,
        textColor: Int,
        accessoryColor: Int,
    ) {
        binding.containerActions.removeAllViews()
        val rows = buildActionRows(menu)

        rows.forEachIndexed { index, row ->
            val rowBinding = ViewMainMenuRowBinding.inflate(LayoutInflater.from(context), binding.containerActions, false)
            rowBinding.textMenuTitle.text = row.title
            rowBinding.textMenuTitle.setTextColor(textColor)
            rowBinding.iconMenu.setImageResource(row.iconRes)
            rowBinding.iconMenu.setColorFilter(accessoryColor)
            rowBinding.iconAccessory.visibility = if (row.showAccessory) View.VISIBLE else View.GONE
            rowBinding.iconAccessory.setColorFilter(accessoryColor)
            rowBinding.root.setOnClickListener {
                popupWindow.dismiss()
                row.onClick()
            }
            binding.containerActions.addView(rowBinding.root)
            if (index < rows.lastIndex) {
                binding.containerActions.addView(makeDivider(dividerColor))
            }
        }

        binding.dividerFont.visibility = if (rows.isEmpty()) View.GONE else View.VISIBLE
    }

    private fun buildActionRows(
        menu: Menu,
    ): List<ReadingActionRow> =
        buildList {
            maybeAddActionRow(menu, R.id.menu_reading_save, R.drawable.ic_saved)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_reading_markunread, R.drawable.ic_indicator_unread)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_send_story, R.drawable.ic_send_to)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_send_story_full, R.drawable.ic_send_to)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_intel, R.drawable.ic_feed_train)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_reading_sharenewsblur, R.drawable.ic_share)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_reading_original, R.drawable.ic_world)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_go_to_feed, R.drawable.ic_story_feed_gray46)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_shortcuts, R.drawable.ic_main_menu_shortcuts)?.let(::add)
        }

    private fun maybeAddActionRow(
        menu: Menu,
        itemId: Int,
        iconRes: Int,
    ): ReadingActionRow? {
        val item = menu.findItem(itemId) ?: return null
        if (!item.isVisible) return null
        return ReadingActionRow(
            title = item.title.toString(),
            iconRes = iconRes,
            onClick = {
                controller.onMenuItemSelected(itemId)
            },
        )
    }

    private fun configureFontRow(
        binding: PopupReadingMenuBinding,
        menu: Menu,
        popupWindow: PopupWindow,
        textColor: Int,
        accessoryColor: Int,
    ) {
        binding.containerFontRow.removeAllViews()

        val fontItem = menu.findItem(R.id.menu_font)
        val fontSubMenu = fontItem?.subMenu
        val hasFontRow = fontItem?.isVisible == true && fontSubMenu != null

        if (!hasFontRow) {
            binding.containerFontRow.visibility = View.GONE
            binding.dividerToggles.visibility = View.GONE
            return
        }

        val rowBinding = ViewMainMenuRowBinding.inflate(LayoutInflater.from(context), binding.containerFontRow, false)
        rowBinding.textMenuTitle.text = selectedFontTitle(fontSubMenu)
        rowBinding.textMenuTitle.setTextColor(textColor)
        rowBinding.iconMenu.setImageResource(R.drawable.ic_story_text_gray46)
        rowBinding.iconMenu.setColorFilter(accessoryColor)
        rowBinding.iconAccessory.visibility = View.VISIBLE
        rowBinding.iconAccessory.setColorFilter(accessoryColor)
        rowBinding.root.setOnClickListener {
            popupWindow.dismiss()
            showFontDialog(fontSubMenu)
        }

        binding.containerFontRow.addView(rowBinding.root)
        binding.containerFontRow.visibility = View.VISIBLE
        binding.dividerToggles.visibility = View.VISIBLE
    }

    private fun configureToggles(
        binding: PopupReadingMenuBinding,
        popupWindow: PopupWindow,
        palette: ReadingPopupPalette,
    ) {
        styleToggleGroup(
            binding.groupTextSize,
            listOf(
                binding.btnTextSizeXs,
                binding.btnTextSizeS,
                binding.btnTextSizeM,
                binding.btnTextSizeL,
                binding.btnTextSizeXl,
                binding.btnTextSizeXxl,
            ),
            palette,
        )
        configureThemeSelector(binding, palette)

        val menu = controller.buildMenuModel()
        binding.groupTextSize.visibility = visibleFor(menu, R.id.menu_text_size)
        binding.groupTheme.visibility = visibleFor(menu, R.id.menu_theme)
        binding.dividerToggles.visibility =
            if (binding.containerFontRow.visibility == View.VISIBLE && (binding.groupTextSize.visibility == View.VISIBLE || binding.groupTheme.visibility == View.VISIBLE)) {
                View.VISIBLE
            } else {
                View.GONE
            }

        applySelections(binding, menu)

        binding.groupTextSize.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnTextSizeXs.id -> handleSelection(binding, popupWindow, R.id.menu_text_size_xs)
                binding.btnTextSizeS.id -> handleSelection(binding, popupWindow, R.id.menu_text_size_s)
                binding.btnTextSizeM.id -> handleSelection(binding, popupWindow, R.id.menu_text_size_m)
                binding.btnTextSizeL.id -> handleSelection(binding, popupWindow, R.id.menu_text_size_l)
                binding.btnTextSizeXl.id -> handleSelection(binding, popupWindow, R.id.menu_text_size_xl)
                binding.btnTextSizeXxl.id -> handleSelection(binding, popupWindow, R.id.menu_text_size_xxl)
            }
        }

        listOf(
            binding.btnThemeAuto to ThemeValue.AUTO,
            binding.btnThemeLight to ThemeValue.LIGHT,
            binding.btnThemeSepia to ThemeValue.SEPIA,
            binding.btnThemeDark to ThemeValue.DARK,
            binding.btnThemeBlack to ThemeValue.BLACK,
        ).forEach { (button, theme) ->
            button.setOnClickListener {
                if (theme == selectedTheme(controller.buildMenuModel())) {
                    updateThemeSelection(binding, theme)
                    return@setOnClickListener
                }
                updateThemeSelection(binding, theme)
                handleSelection(
                    binding = binding,
                    popupWindow = popupWindow,
                    itemId =
                        when (theme) {
                            ThemeValue.AUTO -> R.id.menu_theme_auto
                            ThemeValue.LIGHT -> R.id.menu_theme_light
                            ThemeValue.SEPIA -> R.id.menu_theme_sepia
                            ThemeValue.DARK -> R.id.menu_theme_dark
                            ThemeValue.BLACK -> R.id.menu_theme_black
                        },
                    dismissAfter = true,
                )
            }
        }
    }

    private fun handleSelection(
        binding: PopupReadingMenuBinding,
        popupWindow: PopupWindow,
        itemId: Int,
        dismissAfter: Boolean = false,
    ) {
        controller.onMenuItemSelected(itemId)
        if (dismissAfter) {
            popupWindow.dismiss()
        } else {
            applySelections(binding, controller.buildMenuModel())
        }
    }

    private fun applySelections(
        binding: PopupReadingMenuBinding,
        menu: Menu,
    ) {
        if (menu.findItem(R.id.menu_text_size_xs)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeXs.id)
        if (menu.findItem(R.id.menu_text_size_s)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeS.id)
        if (menu.findItem(R.id.menu_text_size_m)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeM.id)
        if (menu.findItem(R.id.menu_text_size_l)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeL.id)
        if (menu.findItem(R.id.menu_text_size_xl)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeXl.id)
        if (menu.findItem(R.id.menu_text_size_xxl)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeXxl.id)

        updateThemeSelection(binding, selectedTheme(menu))
    }

    private fun selectedTheme(menu: Menu): ThemeValue =
        when {
            menu.findItem(R.id.menu_theme_auto)?.isChecked == true -> ThemeValue.AUTO
            menu.findItem(R.id.menu_theme_light)?.isChecked == true -> ThemeValue.LIGHT
            menu.findItem(R.id.menu_theme_sepia)?.isChecked == true -> ThemeValue.SEPIA
            menu.findItem(R.id.menu_theme_dark)?.isChecked == true -> ThemeValue.DARK
            else -> ThemeValue.BLACK
        }

    private fun styleToggleGroup(
        group: MaterialButtonToggleGroup,
        buttons: List<MaterialButton>,
        palette: ReadingPopupPalette,
    ) {
        val buttonInset = UIUtils.dp2px(context, 3)
        val buttonRadius = UIUtils.dp2px(context, 12)

        group.setPadding(buttonInset, buttonInset, buttonInset, buttonInset)
        group.background =
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = UIUtils.dp2px(context, 17f)
                setColor(ContextCompat.getColor(context, palette.themeGroupBackgroundColor))
                setStroke(UIUtils.dp2px(context, 1), ContextCompat.getColor(context, palette.themeGroupBorderColor))
            }

        val buttonTint =
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(
                    ContextCompat.getColor(context, palette.themeGroupSelectedColor),
                    Color.TRANSPARENT,
                ),
            )
        val textColor =
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(
                    ContextCompat.getColor(context, palette.themeGroupSelectedTextColor),
                    ContextCompat.getColor(context, palette.themeGroupTextColor),
                ),
            )

        buttons.forEach { button ->
            button.backgroundTintList = buttonTint
            button.setTextColor(textColor)
            button.iconTint = textColor
            button.strokeWidth = 0
            button.cornerRadius = buttonRadius
            button.insetTop = 0
            button.insetBottom = 0
            button.minimumHeight = 0
            button.gravity = Gravity.CENTER
            button.textAlignment = View.TEXT_ALIGNMENT_CENTER
            button.setPadding(0, 0, 0, 0)
        }
    }

    private fun configureThemeSelector(
        binding: PopupReadingMenuBinding,
        palette: ReadingPopupPalette,
    ) {
        val buttonInset = UIUtils.dp2px(context, 3)
        val buttonRadius = UIUtils.dp2px(context, 12)

        binding.groupTheme.setPadding(buttonInset, buttonInset, buttonInset, buttonInset)
        binding.groupTheme.background =
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = UIUtils.dp2px(context, 17f)
                setColor(ContextCompat.getColor(context, palette.themeGroupBackgroundColor))
                setStroke(UIUtils.dp2px(context, 1), ContextCompat.getColor(context, palette.themeGroupBorderColor))
            }

        val buttonTint =
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(
                    ContextCompat.getColor(context, palette.themeGroupSelectedColor),
                    Color.TRANSPARENT,
                ),
            )
        val autoTextColors =
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(
                    ContextCompat.getColor(context, palette.themeGroupSelectedTextColor),
                    ContextCompat.getColor(context, palette.themeGroupTextColor),
                ),
            )

        listOf(
            binding.btnThemeAuto,
            binding.btnThemeLight,
            binding.btnThemeSepia,
            binding.btnThemeDark,
            binding.btnThemeBlack,
        ).forEach { button ->
            button.isCheckable = true
            button.backgroundTintList = buttonTint
            button.strokeWidth = 0
            button.cornerRadius = buttonRadius
            button.insetTop = 0
            button.insetBottom = 0
            button.minimumHeight = 0
            button.gravity = Gravity.CENTER
            button.textAlignment = View.TEXT_ALIGNMENT_CENTER
            button.setPadding(0, 0, 0, 0)
        }
        listOf(binding.btnThemeLight, binding.btnThemeSepia, binding.btnThemeDark, binding.btnThemeBlack).forEach { button ->
            button.iconGravity = MaterialButton.ICON_GRAVITY_TEXT_TOP
        }
        binding.btnThemeAuto.setTextColor(autoTextColors)
    }

    private fun updateThemeSelection(
        binding: PopupReadingMenuBinding,
        selectedTheme: ThemeValue,
    ) {
        listOf(
            binding.btnThemeAuto to ThemeValue.AUTO,
            binding.btnThemeLight to ThemeValue.LIGHT,
            binding.btnThemeSepia to ThemeValue.SEPIA,
            binding.btnThemeDark to ThemeValue.DARK,
            binding.btnThemeBlack to ThemeValue.BLACK,
        ).forEach { (button, theme) ->
            button.isChecked = theme == selectedTheme
        }
    }

    private fun showFontDialog(subMenu: SubMenu) {
        val titles = Array(subMenu.size()) { index -> subMenu.getItem(index).title }
        val checkedIndex = (0 until subMenu.size()).firstOrNull { subMenu.getItem(it).isChecked } ?: -1

        MaterialAlertDialogBuilder(context)
            .setTitle(R.string.menu_font)
            .setSingleChoiceItems(titles, checkedIndex) { dialog, which ->
                controller.onMenuItemSelected(subMenu.getItem(which).itemId)
                dialog.dismiss()
            }.show()
    }

    private fun selectedFontTitle(subMenu: SubMenu): String =
        (0 until subMenu.size())
            .firstOrNull { subMenu.getItem(it).isChecked }
            ?.let { subMenu.getItem(it).title.toString() }
            ?: context.getString(R.string.menu_font)

    private fun makeDivider(color: Int): View =
        View(context).apply {
            layoutParams =
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    UIUtils.dp2px(context, 1),
                ).apply {
                    marginStart = UIUtils.dp2px(context, 44)
                    marginEnd = UIUtils.dp2px(context, 14)
                }
            setBackgroundColor(color)
        }

    private fun visibleFor(
        menu: Menu,
        itemId: Int,
    ): Int = if (menu.findItem(itemId)?.isVisible == true) View.VISIBLE else View.GONE

    private fun popupPalette(): ReadingPopupPalette =
        when (resolvedTheme()) {
            ThemeValue.SEPIA ->
                ReadingPopupPalette(
                    backgroundColor = R.color.item_background_sepia,
                    strokeColor = R.color.row_border_sepia,
                    dividerColor = R.color.row_border_sepia,
                    textColor = R.color.text_sepia,
                    accessoryColor = R.color.button_text_sepia,
                    themeGroupBackgroundColor = R.color.segmented_control_background_sepia,
                    themeGroupSelectedColor = R.color.segmented_control_selected_sepia,
                    themeGroupTextColor = R.color.segmented_control_text_sepia,
                    themeGroupSelectedTextColor = R.color.segmented_control_selected_text_sepia,
                    themeGroupBorderColor = R.color.segmented_control_border_sepia,
                )

            ThemeValue.DARK ->
                ReadingPopupPalette(
                    backgroundColor = R.color.gray13,
                    strokeColor = R.color.gray30,
                    dividerColor = R.color.gray30,
                    textColor = R.color.white,
                    accessoryColor = R.color.gray75,
                    themeGroupBackgroundColor = R.color.segmented_control_background_dark,
                    themeGroupSelectedColor = R.color.segmented_control_selected_dark,
                    themeGroupTextColor = R.color.segmented_control_text_dark,
                    themeGroupSelectedTextColor = R.color.segmented_control_selected_text_dark,
                    themeGroupBorderColor = R.color.segmented_control_border_dark,
                )

            ThemeValue.BLACK ->
                ReadingPopupPalette(
                    backgroundColor = R.color.gray13,
                    strokeColor = R.color.gray30,
                    dividerColor = R.color.gray30,
                    textColor = R.color.white,
                    accessoryColor = R.color.gray75,
                    themeGroupBackgroundColor = R.color.segmented_control_background_black,
                    themeGroupSelectedColor = R.color.segmented_control_selected_black,
                    themeGroupTextColor = R.color.segmented_control_text_black,
                    themeGroupSelectedTextColor = R.color.segmented_control_selected_text_black,
                    themeGroupBorderColor = R.color.segmented_control_border_black,
                )

            else ->
                ReadingPopupPalette(
                    backgroundColor = R.color.white,
                    strokeColor = R.color.gray90,
                    dividerColor = R.color.gray85,
                    textColor = R.color.gray20,
                    accessoryColor = R.color.gray55,
                    themeGroupBackgroundColor = R.color.segmented_control_background_light,
                    themeGroupSelectedColor = R.color.segmented_control_selected_light,
                    themeGroupTextColor = R.color.segmented_control_text_light,
                    themeGroupSelectedTextColor = R.color.segmented_control_selected_text_light,
                    themeGroupBorderColor = R.color.segmented_control_border_light,
                )
        }

    private fun resolvedTheme(): ThemeValue =
        when (prefsRepo.getSelectedTheme()) {
            ThemeValue.AUTO -> {
                val nightModeFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                if (nightModeFlags == Configuration.UI_MODE_NIGHT_YES) ThemeValue.DARK else ThemeValue.LIGHT
            }

            else -> prefsRepo.getSelectedTheme()
        }
}

private data class ReadingActionRow(
    val title: String,
    val iconRes: Int,
    val showAccessory: Boolean = false,
    val onClick: () -> Unit,
)

private data class ReadingPopupPalette(
    val backgroundColor: Int,
    val strokeColor: Int,
    val dividerColor: Int,
    val textColor: Int,
    val accessoryColor: Int,
    val themeGroupBackgroundColor: Int,
    val themeGroupSelectedColor: Int,
    val themeGroupTextColor: Int,
    val themeGroupSelectedTextColor: Int,
    val themeGroupBorderColor: Int,
)
