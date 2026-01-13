package com.newsblur.network

import com.newsblur.network.domain.NewsBlurResponse

interface FolderApi {
    suspend fun addFolder(folderName: String): NewsBlurResponse

    suspend fun deleteFolder(
        folderName: String?,
        inFolder: String,
    ): NewsBlurResponse

    suspend fun renameFolder(
        folderName: String?,
        newFolderName: String,
        inFolder: String,
    ): NewsBlurResponse

    suspend fun moveFeedToFolders(
        feedId: String?,
        toFolders: Set<String>,
        inFolders: Set<String>,
    ): NewsBlurResponse
}
