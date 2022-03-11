package com.newsblur.fragment

import android.app.Activity
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
import com.newsblur.network.APIManager
import com.newsblur.service.NBSyncService
import com.newsblur.util.AppConstants
import com.newsblur.util.UIUtils
import com.newsblur.util.executeAsyncTask
import dagger.hilt.android.AndroidEntryPoint
import java.util.*
import javax.inject.Inject

@AndroidEntryPoint
class AddFeedFragment : DialogFragment() {

    @Inject
    lateinit var apiManager: APIManager

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    private lateinit var binding: DialogAddFeedBinding

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val v = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_add_feed, null)
        binding = DialogAddFeedBinding.bind(v)

        val builder = AlertDialog.Builder(requireActivity())
        builder.setTitle("Choose folder for " + requireArguments().getString(FEED_NAME))
        builder.setView(v)
        val adapter = AddFeedAdapter(object : OnFolderClickListener {
            override fun onItemClick(folder: Folder) {
                addFeed(requireActivity(), apiManager, folder.name)
            }
        })
        binding.textAddFolderTitle.setOnClickListener {
            if (binding.containerAddFolder.visibility == View.GONE) {
                binding.containerAddFolder.visibility = View.VISIBLE
            } else {
                binding.containerAddFolder.visibility = View.GONE
            }
        }
        binding.icCreateFolder.setOnClickListener {
            if (binding.inputFolderName.text.isEmpty()) {
                Toast.makeText(requireContext(), R.string.add_folder_name, Toast.LENGTH_SHORT).show()
            } else {
                addFeedToNewFolder(requireActivity(), apiManager, binding.inputFolderName.text.toString())
            }
        }
        binding.recyclerViewFolders.addItemDecoration(DividerItemDecoration(requireContext(), LinearLayoutManager.VERTICAL))
        binding.recyclerViewFolders.adapter = adapter
        adapter.setFolders(dbHelper.folders)
        return builder.create()
    }

    private fun addFeedToNewFolder(activity: Activity, apiManager: APIManager, folderName: String) {
        binding.icCreateFolder.visibility = View.GONE
        binding.progressBar.visibility = View.VISIBLE
        binding.inputFolderName.isEnabled = false

        lifecycleScope.executeAsyncTask(
                doInBackground = {
                    apiManager.addFolder(folderName)
                },
                onPostExecute = {
                    binding.inputFolderName.isEnabled = true
                    if (!it.isError) {
                        binding.containerAddFolder.visibility = View.GONE
                        binding.inputFolderName.text.clear()
                        addFeed(activity, apiManager, folderName)
                    } else {
                        UIUtils.safeToast(activity, R.string.add_folder_error, Toast.LENGTH_SHORT)
                    }
                }
        )
    }

    private fun addFeed(activity: Activity, apiManager: APIManager, folderName: String?) {
        binding.textSyncStatus.visibility = View.VISIBLE
        lifecycleScope.executeAsyncTask(
                doInBackground = {
                    (activity as AddFeedProgressListener).addFeedStarted()
                    val feedUrl = requireArguments().getString(FEED_URI)
                    apiManager.addFeed(feedUrl, folderName)
                },
                onPostExecute = {
                    binding.textSyncStatus.visibility = View.GONE
                    val intent = Intent(activity, Main::class.java)
                    intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
                    if (!it.isError) {
                        // trigger a sync when we return to Main so that the new feed will show up
                        NBSyncService.forceFeedsFolders()
                        intent.putExtra(Main.EXTRA_FORCE_SHOW_FEED_ID, it.feed.feedId)
                    } else {
                        UIUtils.safeToast(activity, R.string.add_feed_error, Toast.LENGTH_SHORT)
                    }
                    activity.startActivity(intent)
                    activity.finish()
                    dismiss()
                }
        )
    }

    private class AddFeedAdapter
    constructor(private val listener: OnFolderClickListener) : RecyclerView.Adapter<FolderViewHolder>() {

        private val folders: MutableList<Folder> = ArrayList()

        override fun onCreateViewHolder(viewGroup: ViewGroup, position: Int): FolderViewHolder {
            val view = LayoutInflater.from(viewGroup.context).inflate(R.layout.row_add_feed_folder, viewGroup, false)
            return FolderViewHolder(view)
        }

        override fun onBindViewHolder(viewHolder: FolderViewHolder, position: Int) {
            val folder = folders[position]
            if (folder.name == AppConstants.ROOT_FOLDER) {
                viewHolder.binding.textFolderTitle.setText(R.string.top_level)
            } else {
                viewHolder.binding.textFolderTitle.text = folder.flatName()
            }
            viewHolder.itemView.setOnClickListener { listener.onItemClick(folder) }
        }

        override fun getItemCount(): Int = folders.size

        fun setFolders(folders: List<Folder>) {
            Collections.sort(folders, Folder.FolderComparator)
            this.folders.clear()
            this.folders.addAll(folders)
            notifyDataSetChanged()
        }

        class FolderViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
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

        @JvmStatic
        fun newInstance(feedUri: String, feedName: String): AddFeedFragment {
            val frag = AddFeedFragment()
            val args = Bundle()
            args.putString(FEED_URI, feedUri)
            args.putString(FEED_NAME, feedName)
            frag.arguments = args
            return frag
        }
    }
}