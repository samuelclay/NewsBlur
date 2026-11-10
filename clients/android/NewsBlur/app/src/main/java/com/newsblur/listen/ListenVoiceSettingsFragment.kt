package com.newsblur.listen

import android.app.Dialog
import android.content.DialogInterface
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.core.os.bundleOf
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.viewModels
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.newsblur.design.ListenPalette
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.NewsBlurBottomSheet
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * ListenVoiceSettingsFragment.kt shows ListenVoiceSettingsSheet.kt, from Now Playing (previews read the story
 * playing, in its language) or from Settings (previews use each voice's own sample).
 */
@AndroidEntryPoint
class ListenVoiceSettingsFragment : BottomSheetDialogFragment() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    @Inject
    lateinit var listenManager: ListenManager

    private val viewModel: ListenVoiceSettingsViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel.initialize(
            storyHash = arguments?.getString(ARG_STORY_HASH),
            language = arguments?.getString(ARG_LANGUAGE),
        )
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog =
        NewsBlurBottomSheet.createDialog(
            this,
            android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE,
        )

    override fun onStart() {
        super.onStart()
        dialog?.let {
            NewsBlurBottomSheet.expandWithTheme(it, prefsRepo.getResolvedTheme(requireContext()))
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        val colors = ListenPalette.colors(prefsRepo.getResolvedTheme(requireContext()))
        val actions =
            ListenVoiceSettingsActions(
                onLanguage = viewModel::selectLanguage,
                onSelectVoice = viewModel::selectVoice,
                onPreviewVoice = viewModel::togglePreview,
                onFilter = viewModel::setFilter,
                onClearFilters = viewModel::clearFilters,
                onSearch = viewModel::setSearch,
                onLoadMore = viewModel::loadMore,
                onRetryLibrary = viewModel::retryLibrary,
                onDelivery = viewModel::selectDelivery,
                onCustomChange = viewModel::previewCustom,
                onCustomDone = viewModel::saveCustom,
                onSpeed = viewModel::setSpeed,
                onAutoContinue = viewModel::setAutoContinue,
                onHighlight = viewModel::setHighlight,
                onRetry = viewModel::retry,
                onUpgrade = { UIUtils.startSubscriptionActivity(requireContext()) },
            )
        return ComposeView(requireContext()).apply {
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            setContent {
                NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                    val state by viewModel.state.collectAsStateWithLifecycle()
                    val playback by listenManager.state.collectAsStateWithLifecycle()
                    ListenVoiceSettingsSheet(
                        state = state,
                        playback = playback,
                        colors = colors,
                        actions = actions,
                    )
                }
            }
        }
    }

    override fun onDismiss(dialog: DialogInterface) {
        viewModel.stopPreview()
        super.onDismiss(dialog)
    }

    companion object {
        const val TAG = "listen_voice_settings"
        private const val ARG_STORY_HASH = "story_hash"
        private const val ARG_LANGUAGE = "language"

        fun show(
            fragmentManager: FragmentManager,
            storyHash: String?,
            language: String?,
        ) {
            if (fragmentManager.isStateSaved ||
                fragmentManager.findFragmentByTag(TAG) != null
            ) {
                return
            }
            ListenVoiceSettingsFragment()
                .apply {
                    arguments = bundleOf(ARG_STORY_HASH to storyHash, ARG_LANGUAGE to language)
                }.show(fragmentManager, TAG)
        }
    }
}
