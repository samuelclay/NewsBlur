package com.newsblur.view

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.TextView
import com.newsblur.R
import com.newsblur.domain.Folder
import com.newsblur.domain.FolderHierarchy
import com.newsblur.util.AppConstants
import com.newsblur.util.UIUtils

/** FolderChoiceAdapter.kt always includes collapsed and empty destinations. */
class FolderChoiceAdapter(
    context: Context,
    folders: Collection<Folder>,
) : ArrayAdapter<Folder>(context, R.layout.row_add_feed_folder, FolderHierarchy(folders).ordered) {
    override fun getView(
        position: Int,
        convertView: View?,
        parent: ViewGroup,
    ): View {
        val view = super.getView(position, convertView, parent) as TextView
        val folder = getItem(position)!!
        view.text = if (folder.name == AppConstants.ROOT_FOLDER) context.getString(R.string.top_level) else folder.name
        view.contentDescription = if (folder.name == AppConstants.ROOT_FOLDER) view.text else folder.flatName()
        view.setPaddingRelative(UIUtils.dp2px(context, 16 + folder.depth() * 28), 0, UIUtils.dp2px(context, 16), 0)
        return view
    }
}
