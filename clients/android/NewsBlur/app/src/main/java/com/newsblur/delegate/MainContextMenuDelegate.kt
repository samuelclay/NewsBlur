package com.newsblur.delegate

import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.MenuItem
import android.view.View
import androidx.appcompat.widget.PopupMenu
import androidx.fragment.app.DialogFragment
import com.newsblur.R
import com.newsblur.activity.*
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.fragment.FolderListFragment
import com.newsblur.fragment.LoginAsDialogFragment
import com.newsblur.fragment.LogoutDialogFragment
import com.newsblur.service.NBSyncService
import com.newsblur.util.ListTextSize
import com.newsblur.util.ListTextSize.Companion.fromSize
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.PrefsUtils
import com.newsblur.util.SpacingStyle
import com.newsblur.util.UIUtils
import com.newsblur.widget.WidgetUtils

interface MainContextMenuDelegate {

    fun onMenuClick(anchor: View, listener: PopupMenu.OnMenuItemClickListener)

    fun onMenuItemClick(item: MenuItem, fragment: FolderListFragment): Boolean
}

class MainContextMenuDelegateImpl(
        private val activity: Main,
        private val dbHelper: BlurDatabaseHelper,
) : MainContextMenuDelegate {

    override fun onMenuClick(anchor: View, listener: PopupMenu.OnMenuItemClickListener) {
        val pm = PopupMenu(activity, anchor)
        val menu = pm.menu
        pm.menuInflater.inflate(R.menu.main, menu)

        if (NBSyncService.isStaff == true) {
            menu.findItem(R.id.menu_loginas).isVisible = true
        }

        when (PrefsUtils.getSelectedTheme(activity)) {
            ThemeValue.LIGHT -> menu.findItem(R.id.menu_theme_light).isChecked = true
            ThemeValue.DARK -> menu.findItem(R.id.menu_theme_dark).isChecked = true
            ThemeValue.BLACK -> menu.findItem(R.id.menu_theme_black).isChecked = true
            ThemeValue.AUTO -> menu.findItem(R.id.menu_theme_auto).isChecked = true
            else -> Unit
        }

        val spacingStyle = PrefsUtils.getSpacingStyle(activity)
        if (spacingStyle == SpacingStyle.COMFORTABLE) {
            menu.findItem(R.id.menu_spacing_comfortable).isChecked = true
        } else if (spacingStyle == SpacingStyle.COMPACT) {
            menu.findItem(R.id.menu_spacing_compact).isChecked = true
        }

        when (fromSize(PrefsUtils.getListTextSize(activity))) {
            ListTextSize.XS -> menu.findItem(R.id.menu_text_size_xs).isChecked = true
            ListTextSize.S -> menu.findItem(R.id.menu_text_size_s).isChecked = true
            ListTextSize.M -> menu.findItem(R.id.menu_text_size_m).isChecked = true
            ListTextSize.L -> menu.findItem(R.id.menu_text_size_l).isChecked = true
            ListTextSize.XL -> menu.findItem(R.id.menu_text_size_xl).isChecked = true
            ListTextSize.XXL -> menu.findItem(R.id.menu_text_size_xxl).isChecked = true
        }

        if (WidgetUtils.hasActiveAppWidgets(activity)) {
            menu.findItem(R.id.menu_widget).isVisible = true
        }

        pm.setOnMenuItemClickListener(listener)
        pm.show()
    }

    override fun onMenuItemClick(item: MenuItem, fragment: FolderListFragment): Boolean = when (item.itemId) {
        R.id.menu_logout -> {
            val newFragment: DialogFragment = LogoutDialogFragment()
            newFragment.show(activity.supportFragmentManager, "dialog")
            true
        }
        R.id.menu_settings -> {
            val settingsIntent = Intent(activity, Settings::class.java)
            activity.startActivity(settingsIntent)
            true
        }
        R.id.menu_widget -> {
            val widgetIntent = Intent(activity, WidgetConfig::class.java)
            activity.startActivity(widgetIntent)
            true
        }
        R.id.menu_feedback_email -> {
            PrefsUtils.sendLogEmail(activity, dbHelper)
            true
        }
        R.id.menu_feedback_post -> {
            try {
                val i = Intent(Intent.ACTION_VIEW)
                i.data = Uri.parse(PrefsUtils.createFeedbackLink(activity, dbHelper))
                activity.startActivity(i)
            } catch (e: Exception) {
                Log.wtf(this.javaClass.name, "device cannot even open URLs to report feedback")
            }
            true
        }
        R.id.menu_text_size_xs -> {
            fragment.setListTextSize(ListTextSize.XS)
            true
        }
        R.id.menu_text_size_s -> {
            fragment.setListTextSize(ListTextSize.S)
            true
        }
        R.id.menu_text_size_m -> {
            fragment.setListTextSize(ListTextSize.M)
            true
        }
        R.id.menu_text_size_l -> {
            fragment.setListTextSize(ListTextSize.L)
            true
        }
        R.id.menu_text_size_xl -> {
            fragment.setListTextSize(ListTextSize.XL)
            true
        }
        R.id.menu_text_size_xxl -> {
            fragment.setListTextSize(ListTextSize.XXL)
            true
        }
        R.id.menu_spacing_comfortable -> {
            fragment.setSpacingStyle(SpacingStyle.COMFORTABLE)
            true
        }
        R.id.menu_spacing_compact -> {
            fragment.setSpacingStyle(SpacingStyle.COMPACT)
            true
        }
        R.id.menu_loginas -> {
            val newFragment: DialogFragment = LoginAsDialogFragment()
            newFragment.show(activity.supportFragmentManager, "dialog")
            true
        }
        R.id.menu_theme_auto -> {
            PrefsUtils.setSelectedTheme(activity, ThemeValue.AUTO)
            UIUtils.restartActivity(activity)
            false
        }
        R.id.menu_theme_light -> {
            PrefsUtils.setSelectedTheme(activity, ThemeValue.LIGHT)
            UIUtils.restartActivity(activity)
            false
        }
        R.id.menu_theme_dark -> {
            PrefsUtils.setSelectedTheme(activity, ThemeValue.DARK)
            UIUtils.restartActivity(activity)
            false
        }
        R.id.menu_theme_black -> {
            PrefsUtils.setSelectedTheme(activity, ThemeValue.BLACK)
            UIUtils.restartActivity(activity)
            false
        }
        R.id.menu_premium_account -> {
            val intent = Intent(activity, Premium::class.java)
            activity.startActivity(intent)
            true
        }
        R.id.menu_mute_sites -> {
            val intent = Intent(activity, MuteConfig::class.java)
            activity.startActivity(intent)
            true
        }
        R.id.menu_import_export -> {
            val intent = Intent(activity, ImportExportActivity::class.java)
            activity.startActivity(intent)
            true
        }
        R.id.menu_notifications -> {
            val intent = Intent(activity, NotificationsActivity::class.java)
            activity.startActivity(intent)
            true
        }
        else -> false
    }
}