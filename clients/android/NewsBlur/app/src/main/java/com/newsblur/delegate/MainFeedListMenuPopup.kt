package com.newsblur.delegate

import android.content.Intent
import com.newsblur.activity.ContactActivity
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import androidx.core.content.ContextCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
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
        configureToggles(binding, popupWindow, anchor)
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
                        title = activity.getString(R.string.contact_us),
                        iconRes = R.drawable.nb_menu_feedback,
                    ) {
                        popupWindow.dismiss()
                        activity.startActivity(Intent(activity, ContactActivity::class.java))
                    },
                )
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
        anchor: View,
    ) {
        binding.groupTextSize.addView(ListMenuSegments.fontSize(activity) { id ->
            val size = ListMenuSegments.fontSizes.getValue(id)
            fragment.setListTextSize(size)
            PopupMenuTextScaler.apply(binding.root, size.size)
            updatePopupLayout(anchor, binding, popupWindow, size.size, isShowing = true)
        })
        binding.groupTheme.addView(ListMenuSegments.theme(activity) { id ->
            val theme = ListMenuSegments.themes.getValue(id)
            if (theme != prefsRepo.getSelectedTheme()) {
                popupWindow.dismiss()
                prefsRepo.setSelectedTheme(theme)
                UIUtils.restartActivity(activity)
            }
        })
        when (prefsRepo.getSpacingStyle()) {
            SpacingStyle.COMFORTABLE -> binding.groupSpacing.check(binding.btnSpacingComfortable.id)
            SpacingStyle.COMPACT -> binding.groupSpacing.check(binding.btnSpacingCompact.id)
        }

        binding.groupSpacing.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            when (checkedId) {
                binding.btnSpacingComfortable.id -> fragment.setSpacingStyle(SpacingStyle.COMFORTABLE)
                binding.btnSpacingCompact.id -> fragment.setSpacingStyle(SpacingStyle.COMPACT)
            }
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
        com.newsblur.util.AnchoredPopover.show(anchor, popupWindow, binding.root.measuredWidth, binding.root.measuredHeight, isShowing)
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
                )

            ThemeValue.DARK ->
                PopupPalette(
                    backgroundColor = R.color.gray13,
                    strokeColor = R.color.gray30,
                    dividerColor = R.color.gray30,
                    textColor = R.color.white,
                    accessoryColor = R.color.gray75,
                )

            ThemeValue.BLACK ->
                PopupPalette(
                    backgroundColor = R.color.gray13,
                    strokeColor = R.color.gray30,
                    dividerColor = R.color.gray30,
                    textColor = R.color.white,
                    accessoryColor = R.color.gray75,
                )

            else ->
                PopupPalette(
                    backgroundColor = R.color.white,
                    strokeColor = R.color.gray90,
                    dividerColor = R.color.gray85,
                    textColor = R.color.gray20,
                    accessoryColor = R.color.gray55,
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
)
