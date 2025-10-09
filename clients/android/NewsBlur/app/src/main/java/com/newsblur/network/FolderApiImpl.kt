package com.newsblur.network

import android.content.ContentValues
import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.util.AppConstants

class FolderApiImpl(
    private val gson: Gson,
    private val networkClient: NetworkClient,
) : FolderApi {
    override suspend fun addFolder(folderName: String): NewsBlurResponse {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_FOLDER, folderName)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_ADD_FOLDER)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun deleteFolder(
        folderName: String?,
        inFolder: String,
    ): NewsBlurResponse {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_FOLDER_TO_DELETE, folderName)
                put(APIConstants.PARAMETER_IN_FOLDER, inFolder)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_DELETE_FOLDER)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun renameFolder(
        folderName: String?,
        newFolderName: String,
        inFolder: String,
    ): NewsBlurResponse {
        val values =
            ContentValues().apply {
                put(APIConstants.PARAMETER_FOLDER_TO_RENAME, folderName)
                put(APIConstants.PARAMETER_NEW_FOLDER_NAME, newFolderName)
                put(APIConstants.PARAMETER_IN_FOLDER, inFolder)
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_RENAME_FOLDER)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun moveFeedToFolders(
        feedId: String?,
        toFolders: Set<String>,
        inFolders: Set<String>,
    ): NewsBlurResponse {
        val values = ValueMultimap()
        for (folder in toFolders) {
            var folder = folder
            if (folder == AppConstants.ROOT_FOLDER) folder = ""
            values.put(APIConstants.PARAMETER_TO_FOLDER, folder)
        }
        for (folder in inFolders) {
            var folder = folder
            if (folder == AppConstants.ROOT_FOLDER) folder = ""
            values.put(APIConstants.PARAMETER_IN_FOLDERS, folder)
        }
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MOVE_FEED_TO_FOLDERS)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }
}
