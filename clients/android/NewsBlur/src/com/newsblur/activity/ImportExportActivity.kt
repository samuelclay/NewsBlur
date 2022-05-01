package com.newsblur.activity

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.MimeTypeMap
import com.google.android.material.snackbar.Snackbar
import com.newsblur.R
import com.newsblur.databinding.ActivityImportExportBinding
import com.newsblur.network.APIConstants
import com.newsblur.network.APIManager
import com.newsblur.service.NBSyncService
import com.newsblur.util.*
import dagger.hilt.android.AndroidEntryPoint
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import javax.inject.Inject


@AndroidEntryPoint
class ImportExportActivity : NbActivity() {

    @Inject
    lateinit var apiManager: APIManager

    private val pickXmlFileRequestCode = 10

    private lateinit var binding: ActivityImportExportBinding

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
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
        binding.btnDownload.setOnClickListener { exportOpmlFile() }
    }

    private fun pickOpmlFile() {
        val mineType = MimeTypeMap.getSingleton().getMimeTypeFromExtension("xml")
        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mineType
        }.also {
            startActivityForResult(it, pickXmlFileRequestCode)
        }
    }

    private fun exportOpmlFile() {
        val exportOpmlUrl = APIConstants.buildUrl(APIConstants.PATH_EXPORT_OPML)
        UIUtils.handleUri(this, Uri.parse(exportOpmlUrl))
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, resultData: Intent?) {
        super.onActivityResult(requestCode, resultCode, resultData)
        if (requestCode == pickXmlFileRequestCode && resultCode == Activity.RESULT_OK) {
            resultData?.data?.also { uri ->
                importOpmlFile(uri)
            }
                    ?: Snackbar.make(
                            binding.root,
                            "OPML file retrieval failed!",
                            Snackbar.LENGTH_LONG
                    ).show()
        }
    }

    override fun handleUpdate(updateType: Int) {
        // ignore
    }
}