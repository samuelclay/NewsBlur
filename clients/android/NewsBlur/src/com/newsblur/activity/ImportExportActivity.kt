package com.newsblur.activity

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.MimeTypeMap
import com.newsblur.R
import com.newsblur.databinding.ActivityImportExportBinding
import com.newsblur.network.APIConstants
import com.newsblur.util.UIUtils
import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader

class ImportExportActivity : NbActivity() {

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

    override fun onActivityResult(requestCode: Int, resultCode: Int, resultData: Intent?) {
        super.onActivityResult(requestCode, resultCode, resultData)
        if (requestCode == pickXmlFileRequestCode && resultCode == Activity.RESULT_OK) {
            // The result data contains a URI for the document or directory that
            // the user selected.
            resultData?.data?.also { uri ->
                // Perform operations on the document using its URI.
                readTextFromUri(uri)
            }
        }
    }

    @Throws(IOException::class)
    private fun readTextFromUri(uri: Uri): String {
        val stringBuilder = StringBuilder()
        contentResolver.openInputStream(uri)?.use { inputStream ->
            BufferedReader(InputStreamReader(inputStream)).use { reader ->
                var line: String? = reader.readLine()
                while (line != null) {
                    stringBuilder.append(line)
                    line = reader.readLine()
                }
            }
        }
        return stringBuilder.toString()
    }

}