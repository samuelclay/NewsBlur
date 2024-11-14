package com.newsblur.activity

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.webkit.MimeTypeMap
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.google.android.material.snackbar.Snackbar
import com.newsblur.R
import com.newsblur.databinding.ActivityImportExportBinding
import com.newsblur.network.APIManager
import com.newsblur.service.NBSyncService
import com.newsblur.util.DownloadCompleteReceiver
import com.newsblur.util.FeedUtils
import com.newsblur.util.FileDownloader
import com.newsblur.util.NBScope
import com.newsblur.util.UIUtils
import com.newsblur.util.executeAsyncTask
import com.newsblur.util.setViewGone
import com.newsblur.util.setViewVisible
import dagger.hilt.android.AndroidEntryPoint
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import javax.inject.Inject

@AndroidEntryPoint
class ImportExportActivity : NbActivity() {

    @Inject
    lateinit var apiManager: APIManager

    private lateinit var binding: ActivityImportExportBinding

    private val filePickResultLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            handleFilePickResult(result.data)
        }
    }

    // used for Android 9 and below
    private val requestWriteStoragePermissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestPermission()) { isGranted ->
        if (isGranted) {
            exportOpmlFile()
        } else {
            Toast.makeText(this, R.string.write_storage_permission_opml, Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityImportExportBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupUI()
        setupListeners()
    }

    private fun setupUI() {
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.import_export_title), true)
    }

    private fun setupListeners() {
        binding.btnUpload.setOnClickListener { pickOpmlFile() }
        binding.btnDownload.setOnClickListener {
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                checkAndRequestWriteStoragePermission()
            } else {
                exportOpmlFile()
            }
        }
    }

    private fun pickOpmlFile() {
        val mineType = MimeTypeMap.getSingleton().getMimeTypeFromExtension("xml")
        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mineType
        }.also {
            filePickResultLauncher.launch(it)
        }
    }

    private fun exportOpmlFile() {
        DownloadCompleteReceiver.expectedFileDownloadId = FileDownloader.exportOpml(this)
        val msg = "${getString(R.string.newsblur_opml)} download started"
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
    }

    private fun importOpmlFile(uri: Uri) {
        NBScope.executeAsyncTask(
                onPreExecute = {
                    binding.btnUpload.setViewGone()
                    binding.progressUpload.setViewVisible()
                },
                doInBackground = {
                    val file = File.createTempFile("opml", ".xml")
                    contentResolver.openInputStream(uri)?.use { input ->
                        file.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                    val requestBody = MultipartBody.Builder()
                            .setType(MultipartBody.FORM)
                            .addFormDataPart("file", file.name, file.asRequestBody())
                            .build()
                    apiManager.importOpml(requestBody)
                },
                onPostExecute = {
                    if (it.isError) {
                        Snackbar.make(
                                binding.root,
                                it.getErrorMessage("Error importing OPML file"),
                                Snackbar.LENGTH_LONG
                        ).show()
                    } else {
                        Snackbar.make(
                                binding.root,
                                "Imported OPML file successfully!",
                                Snackbar.LENGTH_LONG
                        ).show()

                        // refresh all feeds and folders
                        NBSyncService.forceFeedsFolders()
                        FeedUtils.triggerSync(this)
                    }

                    binding.btnUpload.setViewVisible()
                    binding.progressUpload.setViewGone()
                }
        )
    }

    private fun handleFilePickResult(resultData: Intent?) {
        resultData?.data?.also { uri ->
            importOpmlFile(uri)
        } ?: Snackbar.make(
                binding.root,
                "OPML file retrieval failed!",
                Snackbar.LENGTH_LONG
        ).show()
    }

    override fun handleUpdate(updateType: Int) {
        // ignore
    }

    // Android 9 and below
    private fun checkAndRequestWriteStoragePermission() {
        if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE
                ) == PackageManager.PERMISSION_GRANTED) {
            exportOpmlFile()
        } else {
            requestWriteStoragePermissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
    }
}