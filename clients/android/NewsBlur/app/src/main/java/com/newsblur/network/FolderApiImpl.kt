package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.util.AppConstants

class FolderApiImpl(
    private val gson: Gson,
    private val networkClient: NetworkClient,
) : FolderApi {
    override suspend fun addFolder(
        folderName: String,
        parentFolder: String,
    ): NewsBlurResponse {
        if (FolderPath.unavailable(parentFolder)) return unavailableFolder()
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_FOLDER, folderName)
                put("parent_folder", FolderPath.leaf(parentFolder))
                if (FolderPath.supported) put("parent_folder_path", FolderPath.json(parentFolder))
            }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_ADD_FOLDER)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    override suspend fun deleteFolder(
        folderName: String?,
        inFolder: String,
    ): NewsBlurResponse {
        if (FolderPath.unavailable(folderName)) return unavailableFolder()
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_FOLDER_TO_DELETE, FolderPath.leaf(folderName))
                put(APIConstants.PARAMETER_IN_FOLDER, FolderPath.leaf(inFolder))
                if (FolderPath.supported) put("folder_path", FolderPath.json(folderName))
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
        if (FolderPath.unavailable(folderName)) return unavailableFolder()
        val values =
            ValueMultimap().apply {
                put(APIConstants.PARAMETER_FOLDER_TO_RENAME, FolderPath.leaf(folderName))
                put(APIConstants.PARAMETER_NEW_FOLDER_NAME, newFolderName)
                put(APIConstants.PARAMETER_IN_FOLDER, FolderPath.leaf(inFolder))
                if (FolderPath.supported) put("folder_path", FolderPath.json(folderName))
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
        if ((toFolders + inFolders).any(FolderPath::unavailable)) return unavailableFolder()
        val values = ValueMultimap()
        for (folder in toFolders) {
            var folder = folder
            if (folder == AppConstants.ROOT_FOLDER) folder = ""
            values.put(APIConstants.PARAMETER_TO_FOLDER, FolderPath.leaf(folder))
        }
        for (folder in inFolders) {
            var folder = folder
            if (folder == AppConstants.ROOT_FOLDER) folder = ""
            values.put(APIConstants.PARAMETER_IN_FOLDERS, FolderPath.leaf(folder))
        }
        values.put(APIConstants.PARAMETER_FEEDID, feedId)
        if (FolderPath.supported) {
            values.put("to_folder_paths", FolderPath.jsonPaths(toFolders))
            values.put("in_folder_paths", FolderPath.jsonPaths(inFolders))
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_MOVE_FEED_TO_FOLDERS)
        val response: APIResponse = networkClient.post(urlString, values)
        return response.getResponse(gson, NewsBlurResponse::class.java)
    }

    private fun unavailableFolder() =
        NewsBlurResponse().apply {
            message = FolderPath.AMBIGUOUS_FOLDER
            code = -1
        }
}
