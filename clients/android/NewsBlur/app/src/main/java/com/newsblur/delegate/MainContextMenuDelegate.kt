package com.newsblur.delegate

import android.view.View
import com.newsblur.activity.Main
import com.newsblur.fragment.FolderListFragment
import com.newsblur.preference.PrefsRepo
import android.widget.PopupWindow

interface MainContextMenuDelegate {
    fun onMenuClick(anchor: View, fragment: FolderListFragment)
}

class MainContextMenuDelegateImpl(
    private val activity: Main,
    private val prefsRepo: PrefsRepo,
) : MainContextMenuDelegate {
    private var popupWindow: PopupWindow? = null

    override fun onMenuClick(anchor: View, fragment: FolderListFragment) {
        if (popupWindow?.isShowing == true) {
            popupWindow?.dismiss()
            return
        }
        popupWindow =
            MainFeedListMenuPopup(activity, prefsRepo, fragment)
                .show(anchor)
                .also { popup ->
                    popup.setOnDismissListener {
                        if (popupWindow === popup) {
                            popupWindow = null
                        }
                    }
                }
    }
}
