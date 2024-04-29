package com.newsblur.util

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Environment
import android.webkit.MimeTypeMap
import android.widget.Toast
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

class DownloadCompleteReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == DownloadManager.ACTION_DOWNLOAD_COMPLETE) {
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
            if (id == expectedFileDownloadId) {
                context?.let {
                    val msg = "${it.getString(R.string.newsblur_opml)} download completed"
                    Toast.makeText(it, msg, Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    companion object {

        var expectedFileDownloadId: Long? = null
    }
}