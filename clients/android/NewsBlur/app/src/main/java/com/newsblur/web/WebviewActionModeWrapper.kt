package com.newsblur.web

import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import com.newsblur.R

class WebviewActionModeWrapper(
    private val wrapped: ActionMode.Callback?,
    private val delegate: WebviewActionDelegate?,
    private val selectionProvider: JsSelectionProvider, // should already handle any snapshot fallback internally
) : ActionMode.Callback {
    override fun onCreateActionMode(
        mode: ActionMode,
        menu: Menu,
    ): Boolean {
        val created = wrapped?.onCreateActionMode(mode, menu) ?: true
        inject(menu)
        return created
    }

    override fun onPrepareActionMode(
        mode: ActionMode,
        menu: Menu,
    ): Boolean {
        val prepared = wrapped?.onPrepareActionMode(mode, menu) ?: false
        inject(menu)
        return prepared
    }

    override fun onActionItemClicked(
        mode: ActionMode,
        item: MenuItem,
    ): Boolean {
        val action =
            when (item.itemId) {
                ID_MENU_WEB_SEARCH -> WebviewActionType.WEB_SEARCH
                ID_MENU_HIGHLIGHT -> WebviewActionType.HIGHLIGHT
                else -> null
            } ?: return wrapped?.onActionItemClicked(mode, item) ?: false

        selectionProvider.getSelectedText { text ->
            delegate?.onAction(action, text)
            mode.finish()
        }
        return true
    }

    override fun onDestroyActionMode(mode: ActionMode) {
        wrapped?.onDestroyActionMode(mode)
    }

    private fun inject(menu: Menu) {
        if (menu.findItem(ID_MENU_HIGHLIGHT) == null) {
            menu
                .add(Menu.NONE, ID_MENU_HIGHLIGHT, Menu.NONE, R.string.menu_highlight)
                .setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM)
        }
        if (menu.findItem(ID_MENU_WEB_SEARCH) == null) {
            menu
                .add(Menu.NONE, ID_MENU_WEB_SEARCH, Menu.NONE, R.string.menu_web_search)
                .setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM)
        }
    }

    companion object {
        const val ID_MENU_WEB_SEARCH: Int = 0xA11CE001.toInt()
        const val ID_MENU_HIGHLIGHT: Int = 0xA11CE002.toInt()
    }
}
