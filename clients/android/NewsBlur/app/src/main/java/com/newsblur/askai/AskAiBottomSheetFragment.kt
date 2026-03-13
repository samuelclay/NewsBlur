package com.newsblur.askai

import android.Manifest
import android.app.Dialog
import android.content.DialogInterface
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.core.content.ContextCompat
import androidx.core.os.bundleOf
import androidx.fragment.app.viewModels
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.newsblur.R
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.NewsBlurBottomSheet
import com.newsblur.util.UIUtils
import com.newsblur.viewModel.AskAiViewModel
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class AskAiBottomSheetFragment : BottomSheetDialogFragment() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    private val viewModel: AskAiViewModel by viewModels()
    private var voiceRecorder: AskAiVoiceRecorder? = null

    private val microphonePermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) {
                startVoiceRecording()
            } else {
                viewModel.setVoiceError(getString(R.string.ask_ai_microphone_permission_denied))
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel.initialize(
            storyHash = requireArguments().getString(ARG_STORY_HASH).orEmpty(),
            storyTitle = requireArguments().getString(ARG_STORY_TITLE).orEmpty(),
        )
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog = NewsBlurBottomSheet.createDialog(this)

    override fun onStart() {
        super.onStart()
        dialog?.let { NewsBlurBottomSheet.expandWithTheme(it, prefsRepo.getSelectedTheme()) }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View =
        ComposeView(requireContext()).apply {
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            setContent {
                NewsBlurTheme(
                    variant = prefsRepo.getSelectedTheme().toVariant(),
                    dynamic = false,
                ) {
                    val state by viewModel.uiState.collectAsStateWithLifecycle()

                    AskAiSheet(
                        state = state,
                        theme = prefsRepo.getSelectedTheme(),
                        onQuestionSelected = viewModel::sendQuestion,
                        onCustomQuestionChanged = viewModel::updateCustomQuestion,
                        onAskCustomQuestion = { viewModel.sendQuestion(AskAiQuestionType.CUSTOM) },
                        onSendFollowUp = viewModel::sendFollowUp,
                        onReask = { viewModel.reaskWithModel(viewModel.uiState.value.selectedModel) },
                        onModelSelected = viewModel::selectModel,
                        onUpgrade = { UIUtils.startSubscriptionActivity(requireContext()) },
                        onVoiceClick = ::toggleVoiceRecording,
                    )
                }
            }
        }

    override fun onDismiss(dialog: DialogInterface) {
        stopVoiceRecording(cancel = true)
        viewModel.cancelRequest()
        super.onDismiss(dialog)
    }

    override fun onDestroyView() {
        stopVoiceRecording(cancel = true)
        super.onDestroyView()
    }

    private fun toggleVoiceRecording() {
        if (viewModel.uiState.value.isRecording) {
            stopVoiceRecording(cancel = false)
            return
        }

        val hasPermission =
            ContextCompat.checkSelfPermission(
                requireContext(),
                Manifest.permission.RECORD_AUDIO,
            ) == PackageManager.PERMISSION_GRANTED

        if (hasPermission) {
            startVoiceRecording()
        } else {
            microphonePermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    private fun startVoiceRecording() {
        stopVoiceRecording(cancel = true)

        val recorder = AskAiVoiceRecorder(requireContext())
        if (recorder.startRecording()) {
            voiceRecorder = recorder
            viewModel.setRecording(true)
        } else {
            recorder.cancel()
            viewModel.setVoiceError(getString(R.string.ask_ai_microphone_error))
        }
    }

    private fun stopVoiceRecording(cancel: Boolean) {
        val recorder = voiceRecorder ?: return
        voiceRecorder = null

        if (cancel) {
            recorder.cancel()
            viewModel.setRecording(false)
            return
        }

        val audioFile = recorder.stopRecording()
        if (audioFile != null) {
            viewModel.transcribeAudio(audioFile)
        } else {
            viewModel.setVoiceError(getString(R.string.ask_ai_microphone_error))
        }
    }

    companion object {
        const val TAG = "ask_ai_bottom_sheet"

        private const val ARG_STORY_HASH = "story_hash"
        private const val ARG_STORY_TITLE = "story_title"

        @JvmStatic
        fun newInstance(
            storyHash: String,
            storyTitle: String,
        ) = AskAiBottomSheetFragment().apply {
            arguments =
                bundleOf(
                    ARG_STORY_HASH to storyHash,
                    ARG_STORY_TITLE to storyTitle,
                )
        }
    }
}
