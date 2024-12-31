package com.newsblur.domain

data class FolderQueryResult(
        val folders: LinkedHashMap<String, Folder>,
        val flatFolders: LinkedHashMap<String, Folder>,
)
