package com.newsblur.fragment

import android.app.Dialog
import android.content.DialogInterface
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.fragment.app.viewModels
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.newsblur.activity.AddFeedExternal
import com.newsblur.activity.DiscoverSitesActivity
import com.newsblur.activity.FeedSearchActivity
import com.newsblur.activity.Main
import com.newsblur.addsite.AddSiteSheet
import com.newsblur.addsite.AddSiteViewModel
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.di.IconLoader
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SyncServiceState
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedUtils
import com.newsblur.util.ImageLoader
import com.newsblur.util.NewsBlurBottomSheet
import com.newsblur.util.TryFeedStore
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@AndroidEntryPoint
class AddFeedFragment : BottomSheetDialogFragment() {
    @Inject lateinit var dbHelper: BlurDatabaseHelper

    @Inject lateinit var syncServiceState: SyncServiceState

    @Inject lateinit var tryFeedStore: TryFeedStore

    @Inject lateinit var prefsRepo: PrefsRepo

    @Inject @IconLoader
    lateinit var iconLoader: ImageLoader

    private val viewModel: AddSiteViewModel by viewModels()

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog = NewsBlurBottomSheet.createDialog(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycleScope.launch {
            val folders = withContext(Dispatchers.IO) { dbHelper.folders }
            viewModel.setFolders(folders)
        }
    }

    override fun onStart() {
        super.onStart()
        dialog?.let {
            NewsBlurBottomSheet.expandWithTheme(it, prefsRepo.getResolvedTheme(requireContext()))
            it
                .findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
                ?.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View =
        ComposeView(requireContext()).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            setContent {
                NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                    val state by viewModel.state.collectAsStateWithLifecycle()
                    LaunchedEffect(state.submitting) { isCancelable = !state.submitting }
                    LaunchedEffect(state.folderRevision) {
                        if (state.folderRevision > 0) {
                            syncServiceState.forceFeedsFolders()
                            FeedUtils.triggerSync(requireContext())
                        }
                    }
                    LaunchedEffect(state.completedFeedId) {
                        state.completedFeedId?.let { feedId ->
                            if (arguments?.getBoolean(CLEAR_TRY_FEED_ON_SUCCESS) == true) tryFeedStore.clear()
                            syncServiceState.forceFeedsFolders()
                            FeedUtils.triggerSync(requireContext())
                            val host = requireActivity()
                            host.startActivity(
                                Intent(host, Main::class.java).apply {
                                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                    putExtra(Main.EXTRA_FORCE_SHOW_FEED_ID, feedId)
                                },
                            )
                            dismiss()
                            if (host !is Main) host.finish()
                        }
                    }
                    AddSiteSheet(
                        state = state,
                        theme = prefsRepo.getResolvedTheme(requireContext()),
                        iconLoader = iconLoader,
                        onQueryChanged = viewModel::queryChanged,
                        onFolderNameChanged = viewModel::folderNameChanged,
                        onChooseFolder = viewModel::chooseFolder,
                        onToggleFolder = viewModel::toggleNewFolder,
                        onSubmit = viewModel::submit,
                        onDiscover = { tab ->
                            val host = requireActivity()
                            if (host is DiscoverSitesActivity) {
                                host.showDiscovery(tab, state.parent)
                            } else {
                                startActivity(DiscoverSitesActivity.intent(host, tab, state.parent))
                            }
                            dismiss()
                        },
                    )
                }
            }
        }

    override fun onDismiss(dialog: DialogInterface) {
        super.onDismiss(dialog)
        if (activity is FeedSearchActivity || activity is AddFeedExternal) activity?.finish()
    }

    interface AddFeedProgressListener {
        fun addFeedStarted()
    }

    companion object {
        private const val CLEAR_TRY_FEED_ON_SUCCESS = "clear_try_feed_on_success"

        @JvmStatic
        @JvmOverloads
        fun newInstance(
            feedUri: String = "",
            feedName: String = "",
            clearTryFeedOnSuccess: Boolean = false,
            parent: String = AppConstants.ROOT_FOLDER,
        ) = AddFeedFragment().apply {
            arguments =
                Bundle().apply {
                    putString("feed_url", feedUri)
                    putString("feed_name", feedName)
                    putString("parent", parent)
                    putBoolean(CLEAR_TRY_FEED_ON_SUCCESS, clearTryFeedOnSuccess)
                }
        }
    }
}
