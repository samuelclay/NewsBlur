package com.newsblur.listen

import android.app.Dialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.fragment.app.FragmentManager
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

/** ListenNowPlayingFragment.kt shows ListenNowPlayingSheet.kt as a bottom sheet from the mini player. */
@AndroidEntryPoint
class ListenNowPlayingFragment : BottomSheetDialogFragment() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    @Inject
    lateinit var listenManager: ListenManager

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog = NewsBlurBottomSheet.createDialog(this)

    override fun onStart() {
        super.onStart()
        dialog?.let {
            NewsBlurBottomSheet.expandWithTheme(it, prefsRepo.getResolvedTheme(requireContext()))
        }
        listenManager.refreshUpNext()
        // Up Next may have changed on the web or iOS since it was last read.
        listenManager.refreshUpNextQueue()
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        val colors = ListenPalette.colors(prefsRepo.getResolvedTheme(requireContext()))
        return ComposeView(requireContext()).apply {
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            setContent {
                NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                    val state by listenManager.state.collectAsStateWithLifecycle()
                    val icon by listenManager.icon.collectAsStateWithLifecycle()
                    LaunchedEffect(state.isActive) {
                        if (!state.isActive) dismissAllowingStateLoss()
                    }
                    ListenNowPlayingSheet(
                        state = state,
                        icon = icon,
                        colors = colors,
                        onPlayPause = listenManager::togglePlayPause,
                        onSeek = listenManager::seekTo,
                        onSkipBack = listenManager::skipBack,
                        onSkipForward = listenManager::skipForward,
                        onNext = listenManager::playNext,
                        onSpeed = listenManager::setSpeed,
                        onVoiceSettings = {
                            ListenVoiceSettingsFragment.show(
                                parentFragmentManager,
                                storyHash = state.story?.storyHash,
                                language = state.language,
                            )
                        },
                        onRetry = listenManager::retry,
                        onUpgrade = { UIUtils.startSubscriptionActivity(requireContext()) },
                        onPlayQueued = listenManager::playQueued,
                        onRemoveQueued = listenManager::removeFromUpNext,
                        onMoveQueued = listenManager::moveInUpNext,
                    )
                }
            }
        }
    }

    companion object {
        const val TAG = "listen_now_playing"

        fun show(fragmentManager: FragmentManager) {
            if (fragmentManager.isStateSaved ||
                fragmentManager.findFragmentByTag(TAG) != null
            ) {
                return
            }
            ListenNowPlayingFragment().show(fragmentManager, TAG)
        }
    }
}
