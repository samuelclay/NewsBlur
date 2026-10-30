package com.newsblur.fragment

import android.content.Context
import android.widget.Toast
import com.newsblur.R
import com.newsblur.domain.ClassifierScope
import com.newsblur.domain.Folder
import com.newsblur.util.AppConstants

/**
 * The site, folder and global scope toggles on every trainer capsule, after
 * clients/ios/Classes/ScopeToggleView.swift handleTap and media/js/newsblur/reader/reader_classifier.js
 * select_scope: folder and global need Premium Archive, and a site outside every folder has no
 * folder to scope to. IntelTrainerSections.kt and AiClassifierSections.kt share one picker.
 */
class TrainerScopePicker(
    private val context: Context,
    private val canUseWiderScopes: Boolean,
    // The trainer's feed's folder path, or null for a feed that is only at the top level.
    private val folderPath: String?,
) {
    enum class Denial { NEEDS_ARCHIVE, NO_FOLDER }

    val isFolderAvailable: Boolean
        get() = folderPath != null

    /** The scope a toggle of [kind] (ClassifierScope.FEED, FOLDER or GLOBAL) picks, or why it can't. */
    fun resolve(kind: String): Pair<ClassifierScope?, Denial?> =
        when {
            kind == ClassifierScope.FEED -> ClassifierScope.FEED_SCOPE to null
            !canUseWiderScopes -> null to Denial.NEEDS_ARCHIVE
            kind == ClassifierScope.GLOBAL -> ClassifierScope.GLOBAL_SCOPE to null
            // A folder scope without a folder name would save as a global classifier.
            folderPath == null -> null to Denial.NO_FOLDER
            else -> ClassifierScope.folder(folderPath) to null
        }

    /** Applies the scope a toggle picks and briefly names it, or explains why it can't change. */
    fun request(
        kind: String,
        apply: (ClassifierScope) -> Unit,
    ) {
        val (scope, denial) = resolve(kind)
        if (scope == null) {
            val reason = if (denial == Denial.NO_FOLDER) R.string.trainer_scope_no_folder else R.string.ai_scope_requires_archive
            toast(context.getString(reason))
            return
        }
        apply(scope)
        // ScopeToggleView.swift shows the scope it switched to in a tooltip.
        toast(label(scope))
    }

    fun label(scope: ClassifierScope): String =
        when (kind(scope)) {
            ClassifierScope.GLOBAL -> context.getString(R.string.ai_scope_global)
            ClassifierScope.FOLDER ->
                if (scope.folderName.isEmpty()) {
                    context.getString(R.string.ai_scope_folder)
                } else {
                    context.getString(R.string.ai_scope_folder_named, scope.folderName)
                }
            else -> context.getString(R.string.ai_scope_feed)
        }

    private fun toast(text: String) {
        Toast.makeText(context, text, Toast.LENGTH_SHORT).show()
    }

    companion object {
        /** ClassifierScope.FEED, FOLDER or GLOBAL, the toggle a capsule shows as active. */
        @JvmStatic
        fun kind(scope: ClassifierScope): String = if (scope.isFeed) ClassifierScope.FEED else scope.scope

        /** [folder]'s path as apps/reader/models.py flatten_folders names it, like "Blogs - Tumblrs". */
        @JvmStatic
        fun folderPath(folder: Folder): String =
            (folder.parents.filter { it != AppConstants.ROOT_FOLDER } + folder.name).joinToString(" - ")

        /** The first folder holding [feedId], or null for a feed that is only at the top level. */
        @JvmStatic
        fun folderPathOfFeed(
            folders: List<Folder>,
            feedId: String,
        ): String? = folders.firstOrNull { it.name != AppConstants.ROOT_FOLDER && it.feedIds.contains(feedId) }?.let(::folderPath)
    }
}
