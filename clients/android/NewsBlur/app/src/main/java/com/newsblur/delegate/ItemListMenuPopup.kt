package com.newsblur.delegate

import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.LayoutInflater
import android.view.Menu
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import androidx.core.content.ContextCompat
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.newsblur.R
import com.newsblur.activity.ItemsList
import com.newsblur.databinding.PopupItemlistMenuBinding
import com.newsblur.databinding.ViewMainMenuRowBinding
import com.newsblur.util.PrefConstants
import com.newsblur.util.PopupMenuTextScaler
import com.newsblur.util.UIUtils
import kotlin.math.max
import kotlin.math.min

class ItemListMenuPopup(
    private val activity: ItemsList,
    private val controller: Controller,
    private val content: Content = Content.VISUAL,
) {
    enum class Content {
        VISUAL,
        ACTIONS,
    }

    interface Controller {
        fun buildMenuModel(): Menu

        fun onMenuItemSelected(itemId: Int): Boolean
    }

    companion object {
        private val actionItemIds =
            intArrayOf(
                R.id.menu_save_search,
                R.id.menu_rename_folder,
                R.id.menu_mute_folder,
                R.id.menu_unmute_folder,
                R.id.menu_delete_folder,
                R.id.menu_intel,
                R.id.menu_notifications,
                R.id.menu_statistics,
                R.id.menu_rename_feed,
                R.id.menu_instafetch_feed,
                R.id.menu_delete_feed,
                R.id.menu_infrequent_cutoff,
            )

        @JvmStatic
        fun hasVisibleActions(menu: Menu): Boolean = actionItemIds.any { menu.findItem(it)?.isVisible == true }
    }

    fun show(anchor: View): PopupWindow {
        val binding = PopupItemlistMenuBinding.inflate(LayoutInflater.from(activity))
        val popupWindow =
            PopupWindow(
                binding.root,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                true,
            )

        val palette = popupPalette()
        val popupBackground = ContextCompat.getColor(activity, palette.backgroundColor)
        val popupStroke = ContextCompat.getColor(activity, palette.strokeColor)
        val dividerColor = ContextCompat.getColor(activity, palette.dividerColor)
        val textColor = ContextCompat.getColor(activity, palette.textColor)
        val accessoryColor = ContextCompat.getColor(activity, palette.accessoryColor)

        binding.cardMenu.setCardBackgroundColor(popupBackground)
        binding.cardMenu.strokeColor = popupStroke
        binding.dividerActions.setBackgroundColor(dividerColor)

        tintSectionHeaders(binding, textColor, accessoryColor)
        styleToggleGroups(binding, palette)
        configureThemeSelector(binding, palette)
        bindMenu(binding, controller.buildMenuModel(), popupWindow, dividerColor, textColor, accessoryColor, anchor)
        PopupMenuTextScaler.apply(binding.root, activity.prefsRepo.getListTextSize())

        popupWindow.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popupWindow.isOutsideTouchable = true
        popupWindow.isTouchable = true
        popupWindow.inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
        popupWindow.elevation = UIUtils.dp2px(activity, 16f)

        updatePopupLayout(anchor, binding, popupWindow, activity.prefsRepo.getListTextSize(), isShowing = false)
        return popupWindow
    }

    private fun bindMenu(
        binding: PopupItemlistMenuBinding,
        menu: Menu,
        popupWindow: PopupWindow,
        dividerColor: Int,
        textColor: Int,
        accessoryColor: Int,
        anchor: View,
    ) {
        binding.dividerActions.visibility = View.GONE

        when (content) {
            Content.VISUAL -> {
                binding.containerActions.visibility = View.GONE
                hideSections(binding, isVisible = true)
                configureSections(binding, menu, popupWindow, anchor)
            }

            Content.ACTIONS -> {
                binding.containerActions.visibility = View.VISIBLE
                hideSections(binding, isVisible = false)
                configureActionRows(binding, menu, popupWindow, dividerColor, textColor, accessoryColor)
            }
        }
    }

    private fun configureActionRows(
        binding: PopupItemlistMenuBinding,
        menu: Menu,
        popupWindow: PopupWindow,
        dividerColor: Int,
        textColor: Int,
        accessoryColor: Int,
    ) {
        binding.containerActions.removeAllViews()
        val rows = buildActionRows(menu, popupWindow)
        if (rows.isEmpty()) return

        rows.forEachIndexed { index, row ->
            val rowBinding = ViewMainMenuRowBinding.inflate(LayoutInflater.from(activity), binding.containerActions, false)
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
    }

    private fun maybeAddActionRow(
        menu: Menu,
        itemId: Int,
        iconRes: Int,
    ): ActionRow? {
        val item = menu.findItem(itemId) ?: return null
        if (!item.isVisible) return null
        return ActionRow(
            title = item.title.toString(),
            iconRes = iconRes,
            onClick = {
                controller.onMenuItemSelected(itemId)
            },
        )
    }

    private fun buildActionRows(
        menu: Menu,
        popupWindow: PopupWindow,
    ): List<ActionRow> =
        buildList {
            maybeAddActionRow(menu, R.id.menu_rename_folder, R.drawable.ic_file_edit)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_mute_folder, R.drawable.mute_black)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_unmute_folder, R.drawable.mute_black)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_delete_folder, R.drawable.ic_clear)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_intel, R.drawable.ic_feed_train)?.let(::add)
            menu.findItem(R.id.menu_notifications)?.takeIf { it.isVisible }?.let {
                add(
                    ActionRow(
                        title = it.title.toString(),
                        iconRes = R.drawable.nb_menu_notifications,
                        showAccessory = true,
                        onClick = {
                            popupWindow.dismiss()
                            showNotificationsDialog(menu)
                        },
                    ),
                )
            }
            maybeAddActionRow(menu, R.id.menu_statistics, R.drawable.ic_burst)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_rename_feed, R.drawable.ic_file_edit)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_instafetch_feed, R.drawable.ic_cloud_download)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_delete_feed, R.drawable.ic_clear)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_infrequent_cutoff, R.drawable.ic_calendar)?.let(::add)
            maybeAddActionRow(menu, R.id.menu_save_search, R.drawable.ic_search)?.let(::add)
        }

    private fun configureSections(
        binding: PopupItemlistMenuBinding,
        menu: Menu,
        popupWindow: PopupWindow,
        anchor: View,
    ) {
        binding.sectionOrder.visibility = visibleFor(menu, R.id.menu_story_order)
        binding.sectionReadFilter.visibility = visibleFor(menu, R.id.menu_read_filter)
        binding.sectionMarkReadOnScroll.visibility = visibleFor(menu, R.id.menu_mark_read_on_scroll)
        binding.sectionContentPreview.visibility = visibleFor(menu, R.id.menu_story_content_preview_style)
        binding.sectionThumbnailPreview.visibility = visibleFor(menu, R.id.menu_story_thumbnail_style)
        binding.sectionListStyle.visibility = visibleFor(menu, R.id.menu_story_list_style)
        binding.sectionTextSize.visibility = visibleFor(menu, R.id.menu_text_size)
        binding.sectionSpacing.visibility = visibleFor(menu, R.id.menu_spacing)
        binding.sectionTheme.visibility = visibleFor(menu, R.id.menu_theme)

        applySelections(binding, menu)

        binding.groupOrder.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnOrderNewest.id -> handleSelection(binding, popupWindow, R.id.menu_story_order_newest, dismissAfter = true)
                binding.btnOrderOldest.id -> handleSelection(binding, popupWindow, R.id.menu_story_order_oldest, dismissAfter = true)
            }
        }

        binding.groupReadFilter.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnReadFilterAll.id -> handleSelection(binding, popupWindow, R.id.menu_read_filter_all_stories, dismissAfter = true)
                binding.btnReadFilterUnread.id -> handleSelection(binding, popupWindow, R.id.menu_read_filter_unread_only, dismissAfter = true)
            }
        }

        binding.groupMarkReadOnScroll.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnMarkReadOnScrollOff.id -> handleSelection(binding, popupWindow, R.id.menu_mark_read_on_scroll_disabled)
                binding.btnMarkReadOnScrollOn.id -> handleSelection(binding, popupWindow, R.id.menu_mark_read_on_scroll_enabled)
            }
        }

        binding.groupContentPreview.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnContentPreviewNone.id -> handleSelection(binding, popupWindow, R.id.menu_story_content_preview_none)
                binding.btnContentPreviewSmall.id -> handleSelection(binding, popupWindow, R.id.menu_story_content_preview_small)
                binding.btnContentPreviewMedium.id -> handleSelection(binding, popupWindow, R.id.menu_story_content_preview_medium)
                binding.btnContentPreviewLarge.id -> handleSelection(binding, popupWindow, R.id.menu_story_content_preview_large)
            }
        }

        binding.groupThumbnailPreview.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnThumbnailPreviewNone.id -> handleSelection(binding, popupWindow, R.id.menu_story_thumbnail_no_preview)
                binding.btnThumbnailPreviewLeftSmall.id -> handleSelection(binding, popupWindow, R.id.menu_story_thumbnail_left_small)
                binding.btnThumbnailPreviewLeftLarge.id -> handleSelection(binding, popupWindow, R.id.menu_story_thumbnail_left_large)
                binding.btnThumbnailPreviewRightSmall.id -> handleSelection(binding, popupWindow, R.id.menu_story_thumbnail_right_small)
                binding.btnThumbnailPreviewRightLarge.id -> handleSelection(binding, popupWindow, R.id.menu_story_thumbnail_right_large)
            }
        }

        binding.groupListStyle.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnListStyleList.id -> handleSelection(binding, popupWindow, R.id.menu_list_style_list)
                binding.btnListStyleGridC.id -> handleSelection(binding, popupWindow, R.id.menu_list_style_grid_c)
                binding.btnListStyleGridM.id -> handleSelection(binding, popupWindow, R.id.menu_list_style_grid_m)
                binding.btnListStyleGridF.id -> handleSelection(binding, popupWindow, R.id.menu_list_style_grid_f)
            }
        }

        binding.groupTextSize.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnTextSizeXs.id -> handleTextSizeSelection(binding, popupWindow, anchor, R.id.menu_text_size_xs)
                binding.btnTextSizeS.id -> handleTextSizeSelection(binding, popupWindow, anchor, R.id.menu_text_size_s)
                binding.btnTextSizeM.id -> handleTextSizeSelection(binding, popupWindow, anchor, R.id.menu_text_size_m)
                binding.btnTextSizeL.id -> handleTextSizeSelection(binding, popupWindow, anchor, R.id.menu_text_size_l)
                binding.btnTextSizeXl.id -> handleTextSizeSelection(binding, popupWindow, anchor, R.id.menu_text_size_xl)
                binding.btnTextSizeXxl.id -> handleTextSizeSelection(binding, popupWindow, anchor, R.id.menu_text_size_xxl)
            }
        }

        binding.groupSpacing.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnSpacingCompact.id -> handleSelection(binding, popupWindow, R.id.menu_spacing_compact)
                binding.btnSpacingComfortable.id -> handleSelection(binding, popupWindow, R.id.menu_spacing_comfortable)
            }
        }

        listOf(
            Triple(binding.btnThemeAuto, R.id.menu_theme_auto, PrefConstants.ThemeValue.AUTO),
            Triple(binding.btnThemeLight, R.id.menu_theme_light, PrefConstants.ThemeValue.LIGHT),
            Triple(binding.btnThemeSepia, R.id.menu_theme_sepia, PrefConstants.ThemeValue.SEPIA),
            Triple(binding.btnThemeDark, R.id.menu_theme_dark, PrefConstants.ThemeValue.DARK),
            Triple(binding.btnThemeBlack, R.id.menu_theme_black, PrefConstants.ThemeValue.BLACK),
        ).forEach { (button, itemId, theme) ->
            button.setOnClickListener {
                val selectedTheme = selectedTheme(controller.buildMenuModel())
                if (theme == selectedTheme) {
                    updateThemeSelection(binding, theme)
                    return@setOnClickListener
                }
                updateThemeSelection(binding, theme)
                handleSelection(binding, popupWindow, itemId, dismissAfter = true)
            }
        }
    }

    private fun handleSelection(
        binding: PopupItemlistMenuBinding,
        popupWindow: PopupWindow,
        itemId: Int,
        dismissAfter: Boolean = false,
    ) {
        controller.onMenuItemSelected(itemId)
        if (dismissAfter) {
            popupWindow.dismiss()
        } else {
            applySelections(binding, controller.buildMenuModel())
            PopupMenuTextScaler.apply(binding.root, activity.prefsRepo.getListTextSize())
        }
    }

    private fun handleTextSizeSelection(
        binding: PopupItemlistMenuBinding,
        popupWindow: PopupWindow,
        anchor: View,
        itemId: Int,
    ) {
        controller.onMenuItemSelected(itemId)
        applySelections(binding, controller.buildMenuModel())
        val textSize = activity.prefsRepo.getListTextSize()
        PopupMenuTextScaler.apply(binding.root, textSize)
        updatePopupLayout(anchor, binding, popupWindow, textSize, isShowing = true)
    }

    private fun applySelections(
        binding: PopupItemlistMenuBinding,
        menu: Menu,
    ) {
        if (menu.findItem(R.id.menu_story_order_newest)?.isChecked == true) binding.groupOrder.check(binding.btnOrderNewest.id)
        if (menu.findItem(R.id.menu_story_order_oldest)?.isChecked == true) binding.groupOrder.check(binding.btnOrderOldest.id)

        if (menu.findItem(R.id.menu_read_filter_all_stories)?.isChecked == true) binding.groupReadFilter.check(binding.btnReadFilterAll.id)
        if (menu.findItem(R.id.menu_read_filter_unread_only)?.isChecked == true) binding.groupReadFilter.check(binding.btnReadFilterUnread.id)

        if (menu.findItem(R.id.menu_mark_read_on_scroll_disabled)?.isChecked == true) binding.groupMarkReadOnScroll.check(binding.btnMarkReadOnScrollOff.id)
        if (menu.findItem(R.id.menu_mark_read_on_scroll_enabled)?.isChecked == true) binding.groupMarkReadOnScroll.check(binding.btnMarkReadOnScrollOn.id)

        if (menu.findItem(R.id.menu_story_content_preview_none)?.isChecked == true) binding.groupContentPreview.check(binding.btnContentPreviewNone.id)
        if (menu.findItem(R.id.menu_story_content_preview_small)?.isChecked == true) binding.groupContentPreview.check(binding.btnContentPreviewSmall.id)
        if (menu.findItem(R.id.menu_story_content_preview_medium)?.isChecked == true) binding.groupContentPreview.check(binding.btnContentPreviewMedium.id)
        if (menu.findItem(R.id.menu_story_content_preview_large)?.isChecked == true) binding.groupContentPreview.check(binding.btnContentPreviewLarge.id)

        if (menu.findItem(R.id.menu_story_thumbnail_no_preview)?.isChecked == true) binding.groupThumbnailPreview.check(binding.btnThumbnailPreviewNone.id)
        if (menu.findItem(R.id.menu_story_thumbnail_left_small)?.isChecked == true) binding.groupThumbnailPreview.check(binding.btnThumbnailPreviewLeftSmall.id)
        if (menu.findItem(R.id.menu_story_thumbnail_left_large)?.isChecked == true) binding.groupThumbnailPreview.check(binding.btnThumbnailPreviewLeftLarge.id)
        if (menu.findItem(R.id.menu_story_thumbnail_right_small)?.isChecked == true) binding.groupThumbnailPreview.check(binding.btnThumbnailPreviewRightSmall.id)
        if (menu.findItem(R.id.menu_story_thumbnail_right_large)?.isChecked == true) binding.groupThumbnailPreview.check(binding.btnThumbnailPreviewRightLarge.id)

        if (menu.findItem(R.id.menu_list_style_list)?.isChecked == true) binding.groupListStyle.check(binding.btnListStyleList.id)
        if (menu.findItem(R.id.menu_list_style_grid_c)?.isChecked == true) binding.groupListStyle.check(binding.btnListStyleGridC.id)
        if (menu.findItem(R.id.menu_list_style_grid_m)?.isChecked == true) binding.groupListStyle.check(binding.btnListStyleGridM.id)
        if (menu.findItem(R.id.menu_list_style_grid_f)?.isChecked == true) binding.groupListStyle.check(binding.btnListStyleGridF.id)

        if (menu.findItem(R.id.menu_text_size_xs)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeXs.id)
        if (menu.findItem(R.id.menu_text_size_s)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeS.id)
        if (menu.findItem(R.id.menu_text_size_m)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeM.id)
        if (menu.findItem(R.id.menu_text_size_l)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeL.id)
        if (menu.findItem(R.id.menu_text_size_xl)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeXl.id)
        if (menu.findItem(R.id.menu_text_size_xxl)?.isChecked == true) binding.groupTextSize.check(binding.btnTextSizeXxl.id)

        if (menu.findItem(R.id.menu_spacing_compact)?.isChecked == true) binding.groupSpacing.check(binding.btnSpacingCompact.id)
        if (menu.findItem(R.id.menu_spacing_comfortable)?.isChecked == true) binding.groupSpacing.check(binding.btnSpacingComfortable.id)

        updateThemeSelection(
            binding,
            selectedTheme(menu),
        )
    }

    private fun selectedTheme(menu: Menu): PrefConstants.ThemeValue =
        when {
            menu.findItem(R.id.menu_theme_auto)?.isChecked == true -> PrefConstants.ThemeValue.AUTO
            menu.findItem(R.id.menu_theme_light)?.isChecked == true -> PrefConstants.ThemeValue.LIGHT
            menu.findItem(R.id.menu_theme_sepia)?.isChecked == true -> PrefConstants.ThemeValue.SEPIA
            menu.findItem(R.id.menu_theme_dark)?.isChecked == true -> PrefConstants.ThemeValue.DARK
            else -> PrefConstants.ThemeValue.BLACK
        }

    private fun styleToggleGroups(
        binding: PopupItemlistMenuBinding,
        palette: ItemListPopupPalette,
    ) {
        listOf(
            binding.groupOrder to listOf(binding.btnOrderNewest, binding.btnOrderOldest),
            binding.groupReadFilter to listOf(binding.btnReadFilterAll, binding.btnReadFilterUnread),
            binding.groupMarkReadOnScroll to listOf(binding.btnMarkReadOnScrollOff, binding.btnMarkReadOnScrollOn),
            binding.groupContentPreview to listOf(binding.btnContentPreviewNone, binding.btnContentPreviewSmall, binding.btnContentPreviewMedium, binding.btnContentPreviewLarge),
            binding.groupThumbnailPreview to listOf(binding.btnThumbnailPreviewNone, binding.btnThumbnailPreviewLeftSmall, binding.btnThumbnailPreviewLeftLarge, binding.btnThumbnailPreviewRightSmall, binding.btnThumbnailPreviewRightLarge),
            binding.groupListStyle to listOf(binding.btnListStyleList, binding.btnListStyleGridC, binding.btnListStyleGridM, binding.btnListStyleGridF),
            binding.groupTextSize to listOf(binding.btnTextSizeXs, binding.btnTextSizeS, binding.btnTextSizeM, binding.btnTextSizeL, binding.btnTextSizeXl, binding.btnTextSizeXxl),
            binding.groupSpacing to listOf(binding.btnSpacingCompact, binding.btnSpacingComfortable),
        ).forEach { (group, buttons) ->
            styleToggleGroup(group, buttons, palette)
        }
    }

    private fun styleToggleGroup(
        group: MaterialButtonToggleGroup,
        buttons: List<MaterialButton>,
        palette: ItemListPopupPalette,
    ) {
        val buttonInset = UIUtils.dp2px(activity, 4)
        val buttonRadius = UIUtils.dp2px(activity, 7)

        group.setPadding(buttonInset, buttonInset, buttonInset, buttonInset)
        group.background =
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = UIUtils.dp2px(activity, 12f)
                setColor(ContextCompat.getColor(activity, palette.themeGroupBackgroundColor))
                setStroke(UIUtils.dp2px(activity, 1), ContextCompat.getColor(activity, palette.themeGroupBorderColor))
            }

        val buttonTint =
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(
                    ContextCompat.getColor(activity, palette.themeGroupSelectedColor),
                    Color.TRANSPARENT,
                ),
            )
        val textColor =
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(
                    ContextCompat.getColor(activity, palette.themeGroupSelectedTextColor),
                    ContextCompat.getColor(activity, palette.themeGroupTextColor),
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
        binding: PopupItemlistMenuBinding,
        palette: ItemListPopupPalette,
    ) {
        val buttonInset = UIUtils.dp2px(activity, 4)
        val buttonRadius = UIUtils.dp2px(activity, 7)

        binding.groupTheme.setPadding(buttonInset, buttonInset, buttonInset, buttonInset)
        binding.groupTheme.background =
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = UIUtils.dp2px(activity, 12f)
                setColor(ContextCompat.getColor(activity, palette.themeGroupBackgroundColor))
                setStroke(UIUtils.dp2px(activity, 1), ContextCompat.getColor(activity, palette.themeGroupBorderColor))
            }

        val buttonTint =
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(
                    ContextCompat.getColor(activity, palette.themeGroupSelectedColor),
                    Color.TRANSPARENT,
                ),
            )
        val autoTextColors =
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf()),
                intArrayOf(
                    ContextCompat.getColor(activity, palette.themeGroupSelectedTextColor),
                    ContextCompat.getColor(activity, palette.themeGroupTextColor),
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
        binding: PopupItemlistMenuBinding,
        selectedTheme: PrefConstants.ThemeValue,
    ) {
        listOf(
            binding.btnThemeAuto to PrefConstants.ThemeValue.AUTO,
            binding.btnThemeLight to PrefConstants.ThemeValue.LIGHT,
            binding.btnThemeSepia to PrefConstants.ThemeValue.SEPIA,
            binding.btnThemeDark to PrefConstants.ThemeValue.DARK,
            binding.btnThemeBlack to PrefConstants.ThemeValue.BLACK,
        ).forEach { (button, theme) ->
            button.isChecked = theme == selectedTheme
        }
    }

    private fun tintSectionHeaders(
        binding: PopupItemlistMenuBinding,
        textColor: Int,
        accessoryColor: Int,
    ) {
        listOf(
            binding.textSectionOrder,
            binding.textSectionReadFilter,
            binding.textSectionMarkReadOnScroll,
            binding.textSectionContentPreview,
            binding.textSectionThumbnailPreview,
            binding.textSectionListStyle,
            binding.textSectionTextSize,
            binding.textSectionSpacing,
            binding.textSectionTheme,
        ).forEach { it.setTextColor(textColor) }

        listOf(
            binding.iconSectionOrder,
            binding.iconSectionReadFilter,
            binding.iconSectionMarkReadOnScroll,
            binding.iconSectionContentPreview,
            binding.iconSectionThumbnailPreview,
            binding.iconSectionListStyle,
            binding.iconSectionTextSize,
            binding.iconSectionSpacing,
            binding.iconSectionTheme,
        ).forEach { it.setColorFilter(accessoryColor) }
    }

    private fun showNotificationsDialog(menu: Menu) {
        val notificationsItem = menu.findItem(R.id.menu_notifications) ?: return
        val submenu = notificationsItem.subMenu ?: return
        val titles = Array(submenu.size()) { index -> submenu.getItem(index).title }
        val checkedIndex = (0 until submenu.size()).firstOrNull { submenu.getItem(it).isChecked } ?: -1

        val dialog =
            MaterialAlertDialogBuilder(activity)
            .setTitle(notificationsItem.title)
            .setSingleChoiceItems(titles, checkedIndex) { dialog, which ->
                controller.onMenuItemSelected(submenu.getItem(which).itemId)
                dialog.dismiss()
            }.show()
        dialog.window?.decorView?.let { PopupMenuTextScaler.apply(it, activity.prefsRepo.getListTextSize()) }
    }

    private fun applyCardWidth(
        binding: PopupItemlistMenuBinding,
        availableWidthPx: Int,
        preferenceScale: Float,
    ) {
        val popupMargin = UIUtils.dp2px(activity, 8)
        val cardHorizontalMargin = UIUtils.dp2px(activity, 16)
        val baseWidth = UIUtils.dp2px(activity, 320)
        val maxCardWidth = availableWidthPx - (popupMargin * 2) - cardHorizontalMargin
        binding.cardMenu.layoutParams =
            binding.cardMenu.layoutParams.apply {
                width = min(PopupMenuTextScaler.scaledWidthPx(baseWidth, preferenceScale), maxCardWidth).coerceAtLeast(baseWidth)
            }
    }

    private fun updatePopupLayout(
        anchor: View,
        binding: PopupItemlistMenuBinding,
        popupWindow: PopupWindow,
        preferenceScale: Float,
        isShowing: Boolean,
    ) {
        val displayFrame = Rect()
        anchor.getWindowVisibleDisplayFrame(displayFrame)
        applyCardWidth(binding, displayFrame.width(), preferenceScale)
        binding.root.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        val popupWidth = binding.root.measuredWidth
        val margin = UIUtils.dp2px(activity, 8)
        val availableHeight = displayFrame.height() - margin * 2
        val popupHeight = min(binding.root.measuredHeight, availableHeight)
        val location = IntArray(2)
        anchor.getLocationInWindow(location)
        val minX = displayFrame.left + margin
        val maxX = displayFrame.right - popupWidth - margin
        val x =
            (location[0] + anchor.width - popupWidth + UIUtils.dp2px(activity, 4))
                .coerceIn(min(minX, maxX), max(minX, maxX))
        val preferredBelow = location[1] + anchor.height - UIUtils.dp2px(activity, 4)
        val preferredAbove = location[1] - popupHeight + UIUtils.dp2px(activity, 4)
        val y =
            if (preferredBelow + popupHeight <= displayFrame.bottom - margin) {
                preferredBelow
            } else {
                preferredAbove.coerceAtLeast(displayFrame.top + margin)
            }
        if (isShowing) {
            popupWindow.update(x, y, popupWidth, popupHeight)
        } else {
            popupWindow.height = popupHeight
            popupWindow.showAtLocation(anchor.rootView, Gravity.NO_GRAVITY, x, y)
        }
    }

    private fun makeDivider(color: Int): View =
        View(activity).apply {
            layoutParams =
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    UIUtils.dp2px(activity, 1),
                ).apply {
                    marginStart = UIUtils.dp2px(activity, 44)
                    marginEnd = UIUtils.dp2px(activity, 14)
                }
            setBackgroundColor(color)
        }

    private fun visibleFor(
        menu: Menu,
        itemId: Int,
    ): Int = if (menu.findItem(itemId)?.isVisible == true) View.VISIBLE else View.GONE

    private fun hideSections(
        binding: PopupItemlistMenuBinding,
        isVisible: Boolean,
    ) {
        val visibility = if (isVisible) View.VISIBLE else View.GONE
        listOf(
            binding.sectionOrder,
            binding.sectionReadFilter,
            binding.sectionMarkReadOnScroll,
            binding.sectionContentPreview,
            binding.sectionThumbnailPreview,
            binding.sectionListStyle,
            binding.sectionTextSize,
            binding.sectionSpacing,
            binding.sectionTheme,
        ).forEach { it.visibility = visibility }
    }

    private fun popupPalette(): ItemListPopupPalette =
        when (resolvedTheme()) {
            PrefConstants.ThemeValue.SEPIA ->
                ItemListPopupPalette(
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

            PrefConstants.ThemeValue.DARK ->
                ItemListPopupPalette(
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

            PrefConstants.ThemeValue.BLACK ->
                ItemListPopupPalette(
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
                ItemListPopupPalette(
                    backgroundColor = R.color.white,
                    strokeColor = R.color.gray90,
                    dividerColor = R.color.gray85,
                    textColor = R.color.gray20,
                    accessoryColor = R.color.gray55,
                    themeGroupBackgroundColor = R.color.gray90,
                    themeGroupSelectedColor = R.color.white,
                    themeGroupTextColor = R.color.segmented_control_text_light,
                    themeGroupSelectedTextColor = R.color.segmented_control_selected_text_light,
                    themeGroupBorderColor = R.color.gray80,
                )
        }

    private fun resolvedTheme(): PrefConstants.ThemeValue =
        activity.prefsRepo.getResolvedTheme(activity)
}

private data class ActionRow(
    val title: String,
    val iconRes: Int,
    val showAccessory: Boolean = false,
    val onClick: () -> Unit,
)

private data class ItemListPopupPalette(
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
