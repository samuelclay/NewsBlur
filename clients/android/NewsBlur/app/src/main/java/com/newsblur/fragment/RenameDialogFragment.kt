package com.newsblur.fragment

import android.app.Dialog
import android.os.Bundle
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
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
import com.newsblur.viewModel.RenameDialogViewModel
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class RenameDialogFragment : DialogFragment() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    companion object {
        private const val RENAME_TYPE = "rename_type"
        private const val TYPE_FEED = "feed"
        private const val TYPE_FOLDER = "folder"

        private const val FEED_ID = "feed_id"
        private const val FEED_TITLE = "feed_title"

        private const val FOLDER_NAME = "folder_name"
        private const val FOLDER_PARENT = "folder_parent"

        @JvmStatic
        fun newFeedInstance(
            feedId: String,
            feedTitle: String,
        ) = RenameDialogFragment().apply {
            arguments =
                bundleOf(
                    RENAME_TYPE to TYPE_FEED,
                    FEED_ID to feedId,
                    FEED_TITLE to feedTitle,
                )
        }

        @JvmStatic
        fun newFolderInstance(
            folderName: String,
            folderParent: String?,
        ) = RenameDialogFragment().apply {
            arguments =
                bundleOf(
                    RENAME_TYPE to TYPE_FOLDER,
                    FOLDER_NAME to folderName,
                    FOLDER_PARENT to folderParent,
                )
        }
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val type = requireArguments().getString(RENAME_TYPE)!!

        val composeView =
            ComposeView(requireContext()).apply {
                setContent {
                    NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant()) {
                        when (type) {
                            TYPE_FEED -> {
                                val feedId = requireArguments().getString(FEED_ID)!!
                                val feedTitle = requireArguments().getString(FEED_TITLE)!!
                                RenameDialogContent(
                                    type = RenameType.Feed(feedId = feedId, currentTitle = feedTitle),
                                    onDismiss = { dismissAllowingStateLoss() },
                                    onDone = { dismissAllowingStateLoss() },
                                )
                            }

                            else -> {
                                val folderName = requireArguments().getString(FOLDER_NAME)!!
                                val folderParent = requireArguments().getString(FOLDER_PARENT)
                                RenameDialogContent(
                                    type =
                                        RenameType.Folder(
                                            currentName = folderName,
                                            parent = folderParent,
                                        ),
                                    onDismiss = { dismissAllowingStateLoss() },
                                    onDone = { dismissAllowingStateLoss() },
                                )
                            }
                        }
                    }
                }
            }

        return MaterialAlertDialogBuilder(requireContext())
            .setView(composeView)
            .create()
    }
}

sealed interface RenameType {
    data class Feed(
        val feedId: String,
        val currentTitle: String,
    ) : RenameType

    data class Folder(
        val currentName: String,
        val parent: String?,
    ) : RenameType
}

@Composable
fun RenameDialogContent(
    viewModel: RenameDialogViewModel = hiltViewModel(),
    type: RenameType,
    onDismiss: () -> Unit,
    onDone: () -> Unit,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val colors = LocalNbColors.current

    val entityTitle =
        when (type) {
            is RenameType.Feed -> type.currentTitle
            is RenameType.Folder -> type.currentName
        }

    LaunchedEffect(type) {
        when (type) {
            is RenameType.Feed -> viewModel.setInitialText(type.currentTitle)
            is RenameType.Folder -> viewModel.setInitialText(type.currentName)
        }
    }

    LaunchedEffect(state) {
        if (state is RenameDialogViewModel.UiState.Done) onDone()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(12.dp),
        tonalElevation = 6.dp,
        containerColor = colors.itemBackground,
        iconContentColor = MaterialTheme.colorScheme.onSurfaceVariant,
        titleContentColor = colors.textDefault,
        textContentColor = colors.textDefault,
        title = {
            val titleRes =
                when (type) {
                    is RenameType.Feed -> R.string.title_rename_feed
                    is RenameType.Folder -> R.string.title_rename_folder
                }
            Text(
                text = stringResource(titleRes, entityTitle),
                style = MaterialTheme.typography.titleMedium,
            )
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (state is RenameDialogViewModel.UiState.Loading) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        Text(
                            text =
                                when (type) {
                                    is RenameType.Feed -> stringResource(R.string.renaming_feed_message, entityTitle)
                                    is RenameType.Folder -> stringResource(R.string.renaming_folder_message, entityTitle)
                                },
                            style = MaterialTheme.typography.bodyLarge,
                        )
                        Spacer(Modifier.width(12.dp))
                        CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    }
                } else {
                    RenameTextField(
                        value = viewModel.text,
                        onValueChange = viewModel::onTextChanged,
                        isError = state is RenameDialogViewModel.UiState.ValidationError,
                    )

                    if (state is RenameDialogViewModel.UiState.ValidationError) {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = stringResource(R.string.add_folder_name),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                }
            }
        },
        confirmButton = {
            if (state !is RenameDialogViewModel.UiState.Loading) {
                TextButton(
                    onClick = {
                        when (type) {
                            is RenameType.Feed ->
                                viewModel.renameFeed(type.feedId)

                            is RenameType.Folder ->
                                viewModel.renameFolder(type.currentName, type.parent)
                        }
                    },
                ) {
                    Text(
                        text = stringResource(R.string.rename),
                        color = colors.textDefault,
                    )
                }
            }
        },
        dismissButton = {
            if (state !is RenameDialogViewModel.UiState.Loading) {
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

@Composable
private fun RenameTextField(
    value: String,
    onValueChange: (String) -> Unit,
    hintRes: Int = R.string.new_folder_name_hint,
    modifier: Modifier = Modifier,
    isError: Boolean = false,
) {
    Column(
        modifier =
            modifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp),
    ) {
        Spacer(Modifier.height(5.dp))

        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            textStyle = MaterialTheme.typography.bodyLarge,
            placeholder = { Text(stringResource(hintRes)) },
            isError = isError,
            keyboardOptions =
                KeyboardOptions(
                    capitalization = KeyboardCapitalization.Sentences,
                    imeAction = ImeAction.Done,
                ),
        )

        Spacer(Modifier.height(10.dp))
    }
}
