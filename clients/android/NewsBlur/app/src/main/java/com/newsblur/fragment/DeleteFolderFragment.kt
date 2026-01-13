package com.newsblur.fragment

import android.app.Dialog
import android.os.Bundle
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.os.bundleOf
import androidx.fragment.app.DialogFragment
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.newsblur.R
import com.newsblur.design.LocalNbColors
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.preference.PrefsRepo
import com.newsblur.viewModel.DeleteFolderViewModel
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class DeleteFolderDialogFragment : DialogFragment() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    companion object {
        private const val FOLDER_NAME = "folder_name"
        private const val FOLDER_PARENT = "folder_parent"

        @JvmStatic
        fun newInstance(
            folderName: String,
            folderParent: String?,
        ) = DeleteFolderDialogFragment().apply {
            arguments =
                bundleOf(
                    FOLDER_NAME to folderName,
                    FOLDER_PARENT to folderParent,
                )
        }
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val folderName = requireArguments().getString(FOLDER_NAME)!!
        val folderParent = requireArguments().getString(FOLDER_PARENT)

        val composeView =
            ComposeView(requireContext()).apply {
                setContent {
                    NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant()) {
                        DeleteFolderDialogContent(
                            folderName = folderName,
                            folderParent = folderParent,
                            onDismiss = { dismissAllowingStateLoss() },
                            onDeleted = { dismissAllowingStateLoss() },
                        )
                    }
                }
            }

        return MaterialAlertDialogBuilder(requireContext())
            .setView(composeView)
            .create()
    }
}

@Composable
fun DeleteFolderDialogContent(
    viewModel: DeleteFolderViewModel = hiltViewModel(),
    folderName: String,
    folderParent: String?,
    onDismiss: () -> Unit,
    onDeleted: () -> Unit,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val colors = LocalNbColors.current

    LaunchedEffect(state) {
        if (state is DeleteFolderViewModel.UiState.Done) {
            onDeleted()
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(12.dp),
        tonalElevation = 6.dp,
        containerColor = colors.itemBackground,
        iconContentColor = MaterialTheme.colorScheme.onSurfaceVariant,
        titleContentColor = colors.textDefault,
        textContentColor = colors.textDefault,
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (state is DeleteFolderViewModel.UiState.Confirm) {
                    Text(
                        text = stringResource(R.string.delete_folder_message, folderName),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                } else {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        Text(
                            text = stringResource(R.string.deleting_folder_message, folderName),
                            style = MaterialTheme.typography.bodyLarge,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    }
                }
            }
        },
        confirmButton = {
            if (state is DeleteFolderViewModel.UiState.Confirm) {
                TextButton(onClick = { viewModel.deleteFolder(folderName, folderParent) }) {
                    Text(
                        text = stringResource(id = R.string.alert_dialog_ok),
                        color = colors.textDefault,
                    )
                }
            }
        },
        dismissButton = {
            if (state is DeleteFolderViewModel.UiState.Confirm) {
                TextButton(onClick = onDismiss) {
                    Text(
                        text = stringResource(id = R.string.alert_dialog_cancel),
                        color = colors.textDefault,
                    )
                }
            }
        },
    )
}
