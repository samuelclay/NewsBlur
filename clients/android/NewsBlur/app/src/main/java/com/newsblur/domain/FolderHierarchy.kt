package com.newsblur.domain

import com.newsblur.util.AppConstants

/** FolderHierarchy.kt shares path ordering and subtree rules between lists and pickers. */
class FolderHierarchy(folders: Collection<Folder>) {
    private val byPath = folders.associateBy { it.flatName() }
    val ordered: List<Folder> = folders.sortedWith(Folder.FolderComparator)
    private val subtreeFeeds = mutableMapOf<String, Set<String>>()

    fun feedIds(path: String): Set<String> =
        subtreeFeeds.getOrPut(path) {
            val folder = byPath[path]
            if (folder == null) {
                emptySet()
            } else {
                buildSet {
                    addAll(folder.feedIds)
                    folder.children.forEach { addAll(feedIds(folder.childPath(it))) }
                }
            }
        }

    fun visibleFolders(matchingPaths: Set<String>, closedPaths: Set<String>): List<Folder> {
        val included = mutableSetOf(AppConstants.ROOT_FOLDER)
        for (path in matchingPaths) {
            var folder = byPath[path]
            while (folder != null && included.add(folder.flatName())) {
                folder = byPath[folder.parentPath()]
            }
        }
        return ordered.filter { folder ->
            if (folder.flatName() !in included) return@filter false
            var parent = byPath[folder.parentPath()]
            while (parent != null && parent.name != AppConstants.ROOT_FOLDER) {
                if (parent.flatName() in closedPaths) return@filter false
                parent = byPath[parent.parentPath()]
            }
            true
        }
    }
}
