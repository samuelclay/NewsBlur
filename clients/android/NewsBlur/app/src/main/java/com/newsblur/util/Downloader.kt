package com.newsblur.util

import android.app.DownloadManager
import android.content.Context
import android.os.Environment
import android.webkit.MimeTypeMap
import androidx.core.net.toUri
import com.newsblur.R
import com.newsblur.network.APIConstants

object FileDownloader {

    fun exportOpml(context: Context): Long {
        val manager = context.getSystemService(DownloadManager::class.java)
        val url = APIConstants.buildUrl(APIConstants.PATH_EXPORT_OPML)
        val userName = PrefsUtils.getUserName(context)
        val cookie = PrefsUtils.getCookie(context)

        val file = StringBuilder().apply {
            append(context.getString(R.string.newsbluropml))
            userName?.let { append("-$userName") }
            append(".xml")
        }.toString()

        val request = DownloadManager.Request(url.toUri())
                .setMimeType(MimeTypeMap.getSingleton().getMimeTypeFromExtension(".xml"))
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .addRequestHeader("Cookie", cookie)
                .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, file)
                .setTitle(context.getString(R.string.newsblur_opml))
        return manager.enqueue(request)
    }
}