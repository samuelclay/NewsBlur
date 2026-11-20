package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.Folder
import com.newsblur.util.AppConstants

/** FolderPath.kt keeps full identities inside Android and adapts to older servers at the API boundary. */
object FolderPath {
    @JvmStatic @Volatile
    var supported = false

    @Volatile private var knownFolders: Map<String, Folder> = emptyMap()

    @JvmStatic fun setFolders(folders: Collection<Folder>) {
        knownFolders = folders.associateBy { it.flatName() }
    }

    @JvmStatic fun parts(path: String?): List<String> {
        if (path.isNullOrEmpty() || path == AppConstants.ROOT_FOLDER) return emptyList()
        val folder = knownFolders[path]
        return if (folder != null) folder.parents.filter { it != AppConstants.ROOT_FOLDER } + folder.name else path.split(" ▸ ")
    }

    @JvmStatic fun leaf(path: String?): String = parts(path).lastOrNull().orEmpty()

    fun json(path: String?): String = Gson().toJson(parts(path))

    fun jsonPaths(paths: Collection<String>): String = Gson().toJson(paths.map(::parts))

    fun unavailable(path: String?): Boolean {
        if (supported || leaf(path).isEmpty()) return false
        val matches = knownFolders.values.filter { it.name.equals(leaf(path), ignoreCase = true) }
        return matches.size > 1 || (matches.size == 1 && matches.single().flatName() != path)
    }

    @JvmStatic fun serverName(path: String?): String = parts(path).joinToString(" - ")

    const val AMBIGUOUS_FOLDER = "Several folders have this name. Refresh your feeds or choose a uniquely named folder."
}
