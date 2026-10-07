package com.newsblur.image

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.UIUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Copy, Save, and Share for a story photo in StoryImageViewer.kt, handing on the photo's original
 * bytes rather than a re-encoded bitmap, so a GIF stays animated and a PNG keeps its transparency.
 */
object StoryImageActions {
    /** StoryImageViewer.kt opens the public image URL using the browser selected in PrefsRepo.kt. */
    fun openInBrowser(activity: Activity, source: StoryImageSource, prefsRepo: PrefsRepo) {
        val url = source.browserUrl ?: return
        UIUtils.handleUri(activity, prefsRepo, Uri.parse(url))
    }

    // Photos handed to other apps live here, under the FileProvider's cache-path (file_paths.xml).
    private const val SHARED_DIR = "shared_images"

    private const val STORAGE_PERMISSION_REQUEST = 4127

    /** Puts the photo on the clipboard, as a content URI the pasting app can read. */
    suspend fun copy(
        context: Context,
        source: StoryImageSource,
        data: ByteArray,
    ) {
        val uri = sharedUri(context, source, data)
        val clipboard = context.getSystemService(ClipboardManager::class.java) ?: error("No clipboard")
        clipboard.setPrimaryClip(ClipData.newUri(context.contentResolver, source.title, uri))
    }

    /** Opens the share sheet with the photo attached. */
    suspend fun share(
        activity: Activity,
        source: StoryImageSource,
        data: ByteArray,
    ) {
        val uri = sharedUri(activity, source, data)
        val send =
            Intent(Intent.ACTION_SEND).apply {
                type = StoryImageFile.mimeType(data)
                putExtra(Intent.EXTRA_STREAM, uri)
                // The share sheet shows the photo as its preview from the clip.
                clipData = ClipData.newUri(activity.contentResolver, source.title, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        activity.startActivity(Intent.createChooser(send, null))
    }

    /**
     * Whether Save can write to Pictures now. Android 9 and older need the storage permission,
     * which this asks for when it is missing; the reader then taps Save again.
     */
    fun canSave(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) return true
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return true
        }
        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), STORAGE_PERMISSION_REQUEST)
        return false
    }

    /** Saves the photo into Pictures, where Gallery and Google Photos find it. */
    suspend fun save(
        context: Context,
        source: StoryImageSource,
        data: ByteArray,
    ) = withContext(Dispatchers.IO) {
        val mimeType = StoryImageFile.mimeType(data)
        val name = StoryImageFile.fileName(source.url, mimeType)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values =
                ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, name)
                    put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            val uri =
                resolver.insert(MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values)
                    ?: error("MediaStore refused the image")
            try {
                resolver.openOutputStream(uri)?.use { it.write(data) } ?: error("No output stream")
                resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
        } else {
            @Suppress("DEPRECATION")
            val pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            pictures.mkdirs()
            val file = uniqueFile(pictures, name)
            file.writeBytes(data)
            MediaScannerConnection.scanFile(context, arrayOf(file.absolutePath), arrayOf(mimeType), null)
        }
    }

    // The photo's bytes as a file other apps can read through the FileProvider. Only the latest
    // shared photo is kept, since it is only needed until the pasting or sharing app reads it.
    private suspend fun sharedUri(
        context: Context,
        source: StoryImageSource,
        data: ByteArray,
    ): Uri =
        withContext(Dispatchers.IO) {
            val dir = File(context.cacheDir, SHARED_DIR)
            dir.mkdirs()
            dir.listFiles()?.forEach { it.delete() }
            val file = File(dir, StoryImageFile.fileName(source.url, StoryImageFile.mimeType(data)))
            file.writeBytes(data)
            FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        }

    private fun uniqueFile(
        dir: File,
        name: String,
    ): File {
        var file = File(dir, name)
        var copy = 2
        while (file.exists()) {
            file = File(dir, "${name.substringBeforeLast('.')} ($copy).${name.substringAfterLast('.')}")
            copy++
        }
        return file
    }
}
