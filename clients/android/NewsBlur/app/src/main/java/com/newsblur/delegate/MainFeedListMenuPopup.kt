package com.newsblur.delegate

import android.content.Intent
import android.content.res.Configuration
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import androidx.core.content.ContextCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.activity.ImportExportActivity
import com.newsblur.activity.Main
import com.newsblur.activity.MuteConfig
import com.newsblur.activity.NotificationsActivity
import com.newsblur.activity.Profile
import com.newsblur.activity.Settings
import com.newsblur.activity.SubscriptionActivity
import com.newsblur.activity.WidgetConfig
import com.newsblur.databinding.PopupMainMenuBinding
import com.newsblur.databinding.ViewMainMenuRowBinding
import com.newsblur.fragment.FeedsShortcutFragment
import com.newsblur.fragment.FolderListFragment
import com.newsblur.fragment.LoginAsDialogFragment
import com.newsblur.fragment.LogoutDialogFragment
import com.newsblur.fragment.NewslettersFragment
import com.newsblur.keyboard.KeyboardManager
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.ListTextSize
import com.newsblur.util.ListTextSize.Companion.fromSize
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.PopupMenuTextScaler
import com.newsblur.util.SpacingStyle
import com.newsblur.util.UIUtils
import com.newsblur.widget.WidgetUtils
import kotlin.math.min

class MainFeedListMenuPopup(
    private val activity: Main,
    private val prefsRepo: PrefsRepo,
    private val fragment: FolderListFragment,
) {
    fun show(anchor: View): PopupWindow {
        val binding = PopupMainMenuBinding.inflate(LayoutInflater.from(activity))
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
        binding.dividerToggles.setBackgroundColor(dividerColor)

        configureRows(
            binding = binding,
            dividerColor = dividerColor,
            textColor = textColor,
            accessoryColor = accessoryColor,
            popupWindow = popupWindow,
        )
        configureToggles(binding, popupWindow, palette, anchor)
        PopupMenuTextScaler.apply(binding.root, prefsRepo.getListTextSize())

        popupWindow.setBackgroundDrawable(ColorDrawable(android.graphics.Color.TRANSPARENT))
        popupWindow.isOutsideTouchable = true
        popupWindow.isTouchable = true
        popupWindow.inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
        popupWindow.elevation = UIUtils.dp2px(activity, 16f)

        updatePopupLayout(anchor, binding, popupWindow, prefsRepo.getListTextSize(), isShowing = false)
        return popupWindow
    }

    private fun configureRows(
        binding: PopupMainMenuBinding,
        dividerColor: Int,
        textColor: Int,
        accessoryColor: Int,
        popupWindow: PopupWindow,
    ) {
        val rows =
            buildList {
                add(
                    MainMenuRow(
                        title = activity.getString(R.string.main_menu_preferences),
                        iconRes = R.drawable.nb_menu_preferences,
                    ) {
                        popupWindow.dismiss()
                        activity.startActivity(Intent(activity, Settings::class.java))
                    },
                )
                add(
                    MainMenuRow(
                        title = activity.getString(R.string.main_menu_mute_sites),
                        iconRes = R.drawable.nb_menu_mute,
                    ) {
                        popupWindow.dismiss()
                        activity.startActivity(Intent(activity, MuteConfig::class.java))
                    },
                )
                if (WidgetUtils.hasActiveAppWidgets(activity)) {
                    add(
                        MainMenuRow(
                            title = activity.getString(R.string.main_menu_widget_sites),
                            iconRes = R.drawable.nb_menu_widget,
                        ) {
                            popupWindow.dismiss()
                            activity.startActivity(Intent(activity, WidgetConfig::class.java))
                        },
                    )
                }
                add(
                    MainMenuRow(
                        title = activity.getString(R.string.main_menu_notifications),
                        iconRes = R.drawable.nb_menu_notifications,
                    ) {
                        popupWindow.dismiss()
                        activity.startActivity(Intent(activity, NotificationsActivity::class.java))
                    },
                )
                add(
                    MainMenuRow(
                        title = activity.getString(R.string.main_menu_interactions),
                        iconRes = R.drawable.nb_menu_interactions,
                    ) {
                        popupWindow.dismiss()
                        activity.startActivity(Intent(activity, Profile::class.java))
                    },
                )
                add(
                    MainMenuRow(
                        title = getSubscriptionTitle(),
                        iconRes = R.drawable.nb_menu_subscription,
                    ) {
                        popupWindow.dismiss()
                        activity.startActivity(Intent(activity, SubscriptionActivity::class.java))
                    },
                )
                add(
                    MainMenuRow(
                        title = activity.getString(R.string.import_export),
                        iconRes = R.drawable.nb_menu_import_export,
                    ) {
                        popupWindow.dismiss()
                        activity.startActivity(Intent(activity, ImportExportActivity::class.java))
                    },
                )
                add(
                    MainMenuRow(
                        title = activity.getString(R.string.menu_newsletters),
                        iconRes = R.drawable.nb_menu_newsletters,
                    ) {
                        popupWindow.dismiss()
                        NewslettersFragment().show(
                            activity.supportFragmentManager,
                            NewslettersFragment::class.java.name,
                        )
                    },
                )
                if (KeyboardManager.hasHardwareKeyboard(activity)) {
                    add(
                        MainMenuRow(
                            title = activity.getString(R.string.menu_shortcuts),
                            iconRes = R.drawable.ic_main_menu_shortcuts,
                        ) {
                            popupWindow.dismiss()
                            FeedsShortcutFragment().show(
                                activity.supportFragmentManager,
                                FeedsShortcutFragment::class.java.name,
                            )
                        },
                    )
                }
                add(
                    MainMenuRow(
                        title = activity.getString(R.string.menu_feedback),
                        iconRes = R.drawable.nb_menu_feedback,
                        showAccessory = true,
                    ) {
                        popupWindow.dismiss()
                        showFeedbackDialog()
                    },
                )
                if (prefsRepo.getIsStaff()) {
                    add(
                        MainMenuRow(
                            title = activity.getString(R.string.menu_loginas),
                            iconRes = R.drawable.nb_menu_login_as,
                        ) {
                            popupWindow.dismiss()
                            LoginAsDialogFragment().show(activity.supportFragmentManager, "dialog")
                        },
                    )
                }
                add(
                    MainMenuRow(
                        title = activity.getString(R.string.menu_logout),
                        iconRes = R.drawable.nb_menu_logout,
                    ) {
                        popupWindow.dismiss()
                        LogoutDialogFragment().show(activity.supportFragmentManager, "dialog")
                    },
                )
            }

        rows.forEachIndexed { index, row ->
            val rowBinding = ViewMainMenuRowBinding.inflate(LayoutInflater.from(activity), binding.containerItems, false)
            rowBinding.textMenuTitle.text = row.title
            rowBinding.textMenuTitle.setTextColor(textColor)
            rowBinding.iconMenu.setImageResource(row.iconRes)
            rowBinding.iconMenu.setColorFilter(accessoryColor)
            rowBinding.iconAccessory.visibility = if (row.showAccessory) View.VISIBLE else View.GONE
            rowBinding.iconAccessory.setColorFilter(accessoryColor)
            rowBinding.root.setOnClickListener { row.onClick() }
            binding.containerItems.addView(rowBinding.root)
            if (index < rows.lastIndex) {
                binding.containerItems.addView(makeDivider(dividerColor))
            }
        }
    }

    private fun configureToggles(
        binding: PopupMainMenuBinding,
        popupWindow: PopupWindow,
        palette: PopupPalette,
        anchor: View,
    ) {
        configureThemeSelector(binding, palette)

        when (fromSize(prefsRepo.getListTextSize())) {
            ListTextSize.XS -> binding.groupTextSize.check(binding.btnTextSizeXs.id)
            ListTextSize.S -> binding.groupTextSize.check(binding.btnTextSizeS.id)
            ListTextSize.M -> binding.groupTextSize.check(binding.btnTextSizeM.id)
            ListTextSize.L -> binding.groupTextSize.check(binding.btnTextSizeL.id)
            ListTextSize.XL -> binding.groupTextSize.check(binding.btnTextSizeXl.id)
            ListTextSize.XXL -> binding.groupTextSize.check(binding.btnTextSizeXxl.id)
        }

        when (prefsRepo.getSpacingStyle()) {
            SpacingStyle.COMFORTABLE -> binding.groupSpacing.check(binding.btnSpacingComfortable.id)
            SpacingStyle.COMPACT -> binding.groupSpacing.check(binding.btnSpacingCompact.id)
        }

        updateThemeSelection(binding, prefsRepo.getSelectedTheme())

        binding.groupTextSize.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            val textSize =
                when (checkedId) {
                    binding.btnTextSizeXs.id -> ListTextSize.XS
                    binding.btnTextSizeS.id -> ListTextSize.S
                    binding.btnTextSizeM.id -> ListTextSize.M
                    binding.btnTextSizeL.id -> ListTextSize.L
                    binding.btnTextSizeXl.id -> ListTextSize.XL
                    binding.btnTextSizeXxl.id -> ListTextSize.XXL
                    else -> return@addOnButtonCheckedListener
                }
            fragment.setListTextSize(textSize)
            PopupMenuTextScaler.apply(binding.root, textSize.size)
            updatePopupLayout(anchor, binding, popupWindow, textSize.size, isShowing = true)
        }

        binding.groupSpacing.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnSpacingComfortable.id -> fragment.setSpacingStyle(SpacingStyle.COMFORTABLE)
                binding.btnSpacingCompact.id -> fragment.setSpacingStyle(SpacingStyle.COMPACT)
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
                if (theme == prefsRepo.getSelectedTheme()) return@setOnClickListener
                updateThemeSelection(binding, theme)
                popupWindow.dismiss()
                prefsRepo.setSelectedTheme(theme)
                UIUtils.restartActivity(activity)
            }
        }
    }

    private fun configureThemeSelector(
        binding: PopupMainMenuBinding,
        palette: PopupPalette,
    ) {
        val buttonInset = UIUtils.dp2px(activity, 3)
        val buttonRadius = UIUtils.dp2px(activity, 12)

        binding.groupTheme.setPadding(buttonInset, buttonInset, buttonInset, buttonInset)
        binding.groupTheme.background =
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = UIUtils.dp2px(activity, 17f)
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
        binding: PopupMainMenuBinding,
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

    private fun getSubscriptionTitle(): String =
        when {
            prefsRepo.getIsPro() -> activity.getString(R.string.main_menu_premium_pro)
            prefsRepo.getIsArchive() -> activity.getString(R.string.main_menu_premium_archive)
            prefsRepo.getIsPremium() -> activity.getString(R.string.main_menu_upgrade_archive)
            else -> activity.getString(R.string.main_menu_upgrade_premium)
        }

    private fun showFeedbackDialog() {
        val options =
            arrayOf(
                activity.getString(R.string.main_menu_support_forum),
                activity.getString(R.string.menu_feedback_post),
                activity.getString(R.string.menu_feedback_email),
            )

        val dialog =
            MaterialAlertDialogBuilder(activity)
            .setTitle(R.string.menu_feedback)
            .setItems(options) { _, which ->
                when (which) {
                    0 -> UIUtils.handleUri(activity, prefsRepo, Uri.parse("https://forum.newsblur.com"))
                    1 -> UIUtils.handleUri(activity, prefsRepo, Uri.parse(prefsRepo.createFeedbackLink(activity)))
                    2 -> prefsRepo.sendLogEmail(activity)
                }
            }.show()
        dialog.window?.decorView?.let { PopupMenuTextScaler.apply(it, prefsRepo.getListTextSize()) }
    }

    private fun applyCardWidth(
        binding: PopupMainMenuBinding,
        availableWidthPx: Int,
        preferenceScale: Float,
    ) {
        val popupMargin = UIUtils.dp2px(activity, 8)
        val cardHorizontalMargin = UIUtils.dp2px(activity, 16)
        val baseWidth = UIUtils.dp2px(activity, 236)
        val maxCardWidth = availableWidthPx - (popupMargin * 2) - cardHorizontalMargin
        binding.cardMenu.layoutParams =
            binding.cardMenu.layoutParams.apply {
                width = min(PopupMenuTextScaler.scaledWidthPx(baseWidth, preferenceScale), maxCardWidth).coerceAtLeast(baseWidth)
            }
    }

    private fun updatePopupLayout(
        anchor: View,
        binding: PopupMainMenuBinding,
        popupWindow: PopupWindow,
        preferenceScale: Float,
        isShowing: Boolean,
    ) {
        val displayFrame = android.graphics.Rect()
        anchor.getWindowVisibleDisplayFrame(displayFrame)
        applyCardWidth(binding, displayFrame.width(), preferenceScale)
        binding.root.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        val popupWidth = binding.root.measuredWidth
        val popupHeight = binding.root.measuredHeight
        val location = IntArray(2)
        anchor.getLocationInWindow(location)
        val margin = UIUtils.dp2px(activity, 8)
        val x =
            (location[0] + anchor.width - popupWidth + UIUtils.dp2px(activity, 4))
                .coerceIn(displayFrame.left + margin, displayFrame.right - popupWidth - margin)
        val y =
            (location[1] - popupHeight + UIUtils.dp2px(activity, 4))
                .coerceAtLeast(displayFrame.top + margin)
        if (isShowing) {
            popupWindow.update(x, y, popupWidth, popupHeight)
        } else {
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

    private fun popupPalette(): PopupPalette =
        when (resolvedTheme()) {
            ThemeValue.SEPIA ->
                PopupPalette(
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
                PopupPalette(
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
                PopupPalette(
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
                PopupPalette(
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
        prefsRepo.getResolvedTheme(activity)
}

private data class MainMenuRow(
    val title: String,
    val iconRes: Int,
    val showAccessory: Boolean = false,
    val onClick: () -> Unit,
)

private data class PopupPalette(
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
