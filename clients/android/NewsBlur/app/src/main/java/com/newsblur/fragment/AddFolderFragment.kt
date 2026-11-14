package com.newsblur.fragment

import android.app.Dialog
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.DialogFragment
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.DialogAddFolderBinding
import com.newsblur.network.FolderApi
import com.newsblur.service.SyncServiceState
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedUtils
import com.newsblur.view.FolderChoiceAdapter
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@AndroidEntryPoint
class AddFolderFragment : DialogFragment() {
    @Inject lateinit var dbHelper: BlurDatabaseHelper

    @Inject lateinit var folderApi: FolderApi

    @Inject lateinit var syncServiceState: SyncServiceState
    private lateinit var binding: DialogAddFolderBinding
    private var parentFolder = AppConstants.ROOT_FOLDER

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        binding = DialogAddFolderBinding.inflate(layoutInflater)
        parentFolder = savedInstanceState?.getString("parent_folder") ?: AppConstants.ROOT_FOLDER
        updateParent()
        binding.parentFolder.setOnClickListener {
            val choices = FolderChoiceAdapter(requireContext(), dbHelper.folders)
            AlertDialog
                .Builder(requireContext())
                .setTitle(R.string.parent_folder)
                .setAdapter(choices) { _, position ->
                    parentFolder = choices.getItem(position)!!.flatName()
                    updateParent()
                }.show()
        }
        val dialog =
            AlertDialog
                .Builder(requireContext())
                .setTitle(R.string.add_new_folder)
                .setView(binding.root)
                .setNegativeButton(R.string.alert_dialog_cancel, null)
                .setPositiveButton(R.string.add_new_folder, null)
                .create()
        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener { createFolder(dialog) }
        }
        return dialog
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString("parent_folder", parentFolder)
    }

    private fun updateParent() {
        val title = if (parentFolder == AppConstants.ROOT_FOLDER) getString(R.string.top_level) else parentFolder
        binding.parentFolder.text = getString(R.string.new_folder_parent, title)
    }

    private fun createFolder(dialog: AlertDialog) {
        val name =
            binding.folderName.text
                .toString()
                .trim()
        if (name.isEmpty()) {
            binding.folderName.error = getString(R.string.add_folder_name)
            return
        }
        val button = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
        button.isEnabled = false
        binding.parentFolder.isEnabled = false
        binding.folderName.isEnabled = false
        lifecycleScope.launch {
            try {
                val response = withContext(Dispatchers.IO) { folderApi.addFolder(name, parentFolder) }
                if (response.isError) {
                    binding.folderName.error = response.getErrorMessage(getString(R.string.add_folder_error))
                } else {
                    syncServiceState.forceFeedsFolders()
                    FeedUtils.triggerSync(requireContext())
                    Toast.makeText(requireContext(), R.string.folder_added, Toast.LENGTH_SHORT).show()
                    dismiss()
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                binding.folderName.error = getString(R.string.add_folder_error)
            } finally {
                button.isEnabled = true
                binding.parentFolder.isEnabled = true
                binding.folderName.isEnabled = true
            }
        }
    }
}
