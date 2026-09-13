package com.newsblur.fragment

import android.app.Dialog
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.DialogFragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.DividerItemDecoration
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.R
import com.newsblur.activity.Main
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.DialogAddFeedBinding
import com.newsblur.databinding.RowAddFeedFolderBinding
import com.newsblur.domain.Folder
import com.newsblur.fragment.AddFeedFragment.AddFeedAdapter.FolderViewHolder
import com.newsblur.network.FeedApi
import com.newsblur.network.FolderApi
import com.newsblur.service.SyncServiceState
import com.newsblur.util.AppConstants
import com.newsblur.util.TryFeedStore
import com.newsblur.util.UIUtils
import com.newsblur.view.FolderChoiceAdapter
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Collections
import javax.inject.Inject

@AndroidEntryPoint
class AddFeedFragment : DialogFragment() {
    @Inject
    lateinit var folderApi: FolderApi

    @Inject
    lateinit var feedApi: FeedApi

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    @Inject
    lateinit var syncServiceState: SyncServiceState

    @Inject
    lateinit var tryFeedStore: TryFeedStore

    private lateinit var binding: DialogAddFeedBinding
    private var parentFolder = AppConstants.ROOT_FOLDER
    private var submitting = false

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        binding = DialogAddFeedBinding.inflate(layoutInflater)
        parentFolder = savedInstanceState?.getString("parent_folder") ?: AppConstants.ROOT_FOLDER
        updateParentFolder()
        binding.chooseParentFolder.setOnClickListener {
            val choices = FolderChoiceAdapter(requireContext(), dbHelper.folders)
            AlertDialog
                .Builder(requireContext())
                .setTitle(R.string.parent_folder)
                .setAdapter(choices) { _, position ->
                    parentFolder = choices.getItem(position)!!.flatName()
                    updateParentFolder()
                }.show()
        }

        val builder = AlertDialog.Builder(requireActivity())
        builder.setTitle("Choose folder for " + requireArguments().getString(FEED_NAME))
        builder.setView(binding.root)
        val adapter =
            AddFeedAdapter(
                object : OnFolderClickListener {
                    override fun onItemClick(folder: Folder) {
                        addFeed(folder.flatName())
                    }
                },
            )
        binding.textAddFolderTitle.setOnClickListener {
            if (binding.containerAddFolder.visibility == View.GONE) {
                binding.containerAddFolder.visibility = View.VISIBLE
            } else {
                binding.containerAddFolder.visibility = View.GONE
            }
        }
        binding.icCreateFolder.setOnClickListener {
            if (binding.inputFolderName.text.isBlank()) {
                Toast.makeText(requireContext(), R.string.add_folder_name, Toast.LENGTH_SHORT).show()
            } else {
                addFeedToNewFolder(
                    binding.inputFolderName.text
                        .toString()
                        .trim(),
                )
            }
        }
        binding.recyclerViewFolders.addItemDecoration(DividerItemDecoration(requireContext(), LinearLayoutManager.VERTICAL))
        binding.recyclerViewFolders.adapter = adapter
        adapter.setFolders(dbHelper.folders)
        return builder.create()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString("parent_folder", parentFolder)
    }

    private fun updateParentFolder() {
        val title = if (parentFolder == AppConstants.ROOT_FOLDER) getString(R.string.top_level) else parentFolder
        binding.chooseParentFolder.text = getString(R.string.new_folder_parent, title)
    }

    private fun setSubmitting(value: Boolean) {
        submitting = value
        binding.inputFolderName.isEnabled = !value
        binding.chooseParentFolder.isEnabled = !value
        binding.icCreateFolder.isEnabled = !value
    }

    private fun addFeedToNewFolder(folderName: String) {
        if (submitting) return
        setSubmitting(true)
        binding.icCreateFolder.visibility = View.GONE
        binding.progressBar.visibility = View.VISIBLE
        val destinationParent = parentFolder
        lifecycleScope.launch {
            try {
                val response = withContext(Dispatchers.IO) { folderApi.addFolder(folderName, destinationParent) }
                if (response.isError) {
                    Toast.makeText(activity, response.getErrorMessage(getString(R.string.add_folder_error)), Toast.LENGTH_SHORT).show()
                } else {
                    syncServiceState.forceFeedsFolders()
                    binding.containerAddFolder.visibility = View.GONE
                    binding.inputFolderName.text.clear()
                    setSubmitting(false)
                    addFeed(if (destinationParent == AppConstants.ROOT_FOLDER) folderName else "$destinationParent ▸ $folderName")
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                Toast.makeText(activity, R.string.add_folder_error, Toast.LENGTH_SHORT).show()
            } finally {
                if (binding.containerSyncStatus.visibility != View.VISIBLE) setSubmitting(false)
                binding.icCreateFolder.visibility = View.VISIBLE
                binding.progressBar.visibility = View.GONE
            }
        }
    }

    private fun addFeed(folderName: String?) {
        if (submitting) return
        setSubmitting(true)
        binding.containerSyncStatus.visibility = View.VISIBLE
        (activity as? AddFeedProgressListener)?.addFeedStarted()
        val feedUrl = requireArguments().getString(FEED_URI)
        lifecycleScope.launch {
            try {
                val response = withContext(Dispatchers.IO) { feedApi.addFeed(feedUrl, folderName) }
                if (response == null || response.isError) {
                    Toast
                        .makeText(
                            activity,
                            response?.getErrorMessage(getString(R.string.add_feed_error)) ?: getString(R.string.add_feed_error),
                            Toast.LENGTH_SHORT,
                        ).show()
                    return@launch
                }
                if (requireArguments().getBoolean(CLEAR_TRY_FEED_ON_SUCCESS, false)) tryFeedStore.clear()
                syncServiceState.forceFeedsFolders()
                val intent =
                    Intent(activity, Main::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra(Main.EXTRA_FORCE_SHOW_FEED_ID, response.feed.feedId)
                    }
                activity?.startActivity(intent)
                activity?.finish()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                Toast.makeText(activity, R.string.add_feed_error, Toast.LENGTH_SHORT).show()
            } finally {
                binding.containerSyncStatus.visibility = View.GONE
                setSubmitting(false)
            }
        }
    }

    private class AddFeedAdapter(
        private val listener: OnFolderClickListener,
    ) : RecyclerView.Adapter<FolderViewHolder>() {
        private val folders: MutableList<Folder> = ArrayList()

        override fun onCreateViewHolder(
            viewGroup: ViewGroup,
            position: Int,
        ): FolderViewHolder {
            val view = LayoutInflater.from(viewGroup.context).inflate(R.layout.row_add_feed_folder, viewGroup, false)
            return FolderViewHolder(view)
        }

        override fun onBindViewHolder(
            viewHolder: FolderViewHolder,
            position: Int,
        ) {
            val folder = folders[position]
            if (folder.name == AppConstants.ROOT_FOLDER) {
                viewHolder.binding.textFolderTitle.setText(R.string.top_level)
            } else {
                viewHolder.binding.textFolderTitle.text = folder.name
            }
            viewHolder.itemView.setPaddingRelative(
                UIUtils.dp2px(viewHolder.itemView.context, 16 + 28 * folder.depth()),
                0,
                UIUtils.dp2px(viewHolder.itemView.context, 16),
                0,
            )
            viewHolder.itemView.contentDescription =
                if (folder.name == AppConstants.ROOT_FOLDER) viewHolder.binding.textFolderTitle.text else folder.flatName()
            viewHolder.itemView.setOnClickListener { listener.onItemClick(folder) }
        }

        override fun getItemCount(): Int = folders.size

        fun setFolders(folders: List<Folder>) {
            Collections.sort(folders, Folder.FolderComparator)
            this.folders.clear()
            this.folders.addAll(folders)
            this.notifyDataSetChanged()
        }

        class FolderViewHolder(
            itemView: View,
        ) : RecyclerView.ViewHolder(itemView) {
            val binding: RowAddFeedFolderBinding = RowAddFeedFolderBinding.bind(itemView)
        }
    }

    interface AddFeedProgressListener {
        fun addFeedStarted()
    }

    interface OnFolderClickListener {
        fun onItemClick(folder: Folder)
    }

    companion object {
        private const val FEED_URI = "feed_url"
        private const val FEED_NAME = "feed_name"
        private const val CLEAR_TRY_FEED_ON_SUCCESS = "clear_try_feed_on_success"

        @JvmStatic
        @JvmOverloads
        fun newInstance(
            feedUri: String,
            feedName: String,
            clearTryFeedOnSuccess: Boolean = false,
        ): AddFeedFragment {
            val frag = AddFeedFragment()
            val args = Bundle()
            args.putString(FEED_URI, feedUri)
            args.putString(FEED_NAME, feedName)
            args.putBoolean(CLEAR_TRY_FEED_ON_SUCCESS, clearTryFeedOnSuccess)
            frag.arguments = args
            return frag
        }
    }
}
