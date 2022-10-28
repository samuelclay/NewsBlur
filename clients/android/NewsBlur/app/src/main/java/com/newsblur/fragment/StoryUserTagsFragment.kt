package com.newsblur.fragment

import android.app.Dialog
import android.database.Cursor
import android.os.Bundle
import android.view.View
import android.view.animation.AnimationUtils
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.core.view.isVisible
import androidx.fragment.app.DialogFragment
import androidx.lifecycle.ViewModelProvider
import com.newsblur.R
import com.newsblur.databinding.DialogStoryUserTagsBinding
import com.newsblur.databinding.RowSavedTagBinding
import com.newsblur.domain.StarredCount
import com.newsblur.domain.Story
import com.newsblur.service.NBSyncService
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.TagsAdapter
import com.newsblur.viewModel.StoryUserTagsViewModel
import dagger.hilt.android.AndroidEntryPoint
import java.util.*
import javax.inject.Inject
import kotlin.collections.ArrayList
import kotlin.collections.HashMap
import kotlin.collections.HashSet

@AndroidEntryPoint
class StoryUserTagsFragment : DialogFragment(), TagsAdapter.OnTagClickListener {

    @Inject
    lateinit var feedUtils: FeedUtils

    private lateinit var story: Story
    private lateinit var fs: FeedSet
    private lateinit var binding: DialogStoryUserTagsBinding
    private lateinit var storyUserTagsViewModel: StoryUserTagsViewModel

    private lateinit var otherTagsAdapter: TagsAdapter
    private lateinit var savedTagsAdapter: TagsAdapter

    private val otherTags = HashMap<String, StarredCount>()
    private val savedTags = HashSet<StarredCount>()
    private val newTags = HashSet<StarredCount>()

    companion object {

        fun newInstance(story: Story, fs: FeedSet): StoryUserTagsFragment {
            val fragment = StoryUserTagsFragment()
            val args = Bundle()
            args.putSerializable("story", story)
            args.putSerializable("feed_set", fs)
            fragment.arguments = args
            return fragment
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        storyUserTagsViewModel = ViewModelProvider(this).get(StoryUserTagsViewModel::class.java)
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        super.onCreateDialog(savedInstanceState)
        val view = layoutInflater.inflate(R.layout.dialog_story_user_tags, null)
        binding = DialogStoryUserTagsBinding.bind(view)

        savedTagsAdapter = TagsAdapter(TagsAdapter.Type.SAVED, this)
        binding.listSavedTags.adapter = savedTagsAdapter
        otherTagsAdapter = TagsAdapter(TagsAdapter.Type.OTHER, this)
        binding.listOtherTags.adapter = otherTagsAdapter

        story = requireArguments().getSerializable("story") as Story
        fs = requireArguments().getSerializable("feed_set") as FeedSet

        storyUserTagsViewModel.savedStoryCountsLiveData.observe(this) {
            setCursor(it)
        }

        binding.textAddNewTag.setOnClickListener {
            if (binding.containerAddTag.isVisible) {
                val fadeOutAnim = AnimationUtils.loadAnimation(requireContext(), R.anim.fade_out)
                binding.containerAddTag.startAnimation(fadeOutAnim)
                binding.containerAddTag.visibility = View.GONE
            } else {
                val fadeInAnim = AnimationUtils.loadAnimation(requireContext(), R.anim.fade_in)
                binding.containerAddTag.startAnimation(fadeInAnim)
                binding.containerAddTag.visibility = View.VISIBLE
            }
        }

        binding.icCreateTag.setOnClickListener {
            if (binding.inputTagName.text.isEmpty()) {
                Toast.makeText(requireContext(), R.string.add_tag_name, Toast.LENGTH_SHORT).show()
            } else {
                val sc = StarredCount()
                sc.tag = binding.inputTagName.text.toString()
                sc.count = 1
                processNewTag(sc)
            }
        }

        val builder = AlertDialog.Builder(requireActivity())
        builder.setTitle("Saved Tags")
        builder.setView(view)
        builder.setNegativeButton(R.string.alert_dialog_cancel, null)
        builder.setPositiveButton(R.string.dialog_story_tags_save) { _, _ -> saveTags() }

        story.tags.forEach {
            val rowSavedTag = layoutInflater.inflate(R.layout.row_saved_tag, null)
            val viewBinding = RowSavedTagBinding.bind(rowSavedTag)
            viewBinding.containerRow.setBackgroundResource(android.R.color.transparent)
            viewBinding.rowSavedTagSum.visibility = View.GONE
            viewBinding.rowTagName.text = it
            binding.containerStoryTags.addView(rowSavedTag)
        }

        if (story.tags.isEmpty()) {
            binding.textStoryTags.visibility = View.GONE
            binding.containerStoryTags.visibility = View.GONE
        }

        storyUserTagsViewModel.getSavedStoryCounts()

        return builder.create()
    }

    private fun setCursor(cursor: Cursor) {
        if (!cursor.isBeforeFirst) return
        val starredTags = ArrayList<StarredCount>()
        while (cursor.moveToNext()) {
            val sc = StarredCount.fromCursor(cursor)
            if (sc.tag != null && !sc.isTotalCount) {
                starredTags.add(sc)
            }
        }
        Collections.sort(starredTags, StarredCount.StarredCountComparatorByTag)
        setTags(starredTags)
    }

    private fun processNewTag(newTag: StarredCount) {
        var foundExistingTag = false
        if (otherTags.contains(newTag.tag)) {
            val existingTag = otherTags[newTag.tag]!!
            otherTags.remove(existingTag.tag)
            existingTag.count += 1
            savedTags.add(existingTag)
            foundExistingTag = true
        }

        if (!foundExistingTag) {
            savedTags.forEach {
                if (it.tag == newTag.tag) {
                    foundExistingTag = true
                    return@forEach
                }
            }
        }

        if (!foundExistingTag) {
            newTags.add(newTag)
            savedTags.add(newTag)
        }

        updateListAdapters()
        binding.inputTagName.text.clear()
    }

    private fun setTags(starredTags: ArrayList<StarredCount>) {
        otherTags.clear()
        starredTags.forEach { otherTags[it.tag] = it }

        savedTags.clear()
        story.userTags.forEach {
            if (otherTags.containsKey(it)) {
                savedTags.add(otherTags[it]!!)
                otherTags.remove(it)
            }
        }
        updateListAdapters()
    }

    override fun onTagClickListener(starredTag: StarredCount, type: TagsAdapter.Type) {
        if (type == TagsAdapter.Type.OTHER) {
            otherTags.remove(starredTag.tag)
            // tag story count increases because the story
            // supposedly will be saved with it
            starredTag.count += 1
            savedTags.add(starredTag)
        } else if (type == TagsAdapter.Type.SAVED) {
            savedTags.remove(starredTag)
            if (newTags.contains(starredTag)) {
                // discard newly created unsaved tags
                newTags.remove(starredTag)
            } else {
                // tag story count decreases because the story
                // supposedly won't be saved with it
                starredTag.count -= 1
                otherTags[starredTag.tag] = starredTag
            }
        }
        updateListAdapters()
    }

    private fun updateListAdapters() {
        otherTagsAdapter.replaceAll(otherTags.values)
        savedTagsAdapter.replaceAll(savedTags)

        if (otherTags.isNotEmpty()) {
            binding.textOtherTags.visibility = View.VISIBLE
            binding.listOtherTags.visibility = View.VISIBLE
        } else {
            binding.textOtherTags.visibility = View.GONE
            binding.listOtherTags.visibility = View.GONE
        }

        if (savedTags.isNotEmpty()) {
            binding.textSavedTags.visibility = View.VISIBLE
            binding.listSavedTags.visibility = View.VISIBLE
        } else {
            binding.textSavedTags.visibility = View.GONE
            binding.listSavedTags.visibility = View.GONE
        }
    }

    private fun getSavedTagsList(): ArrayList<String> {
        val tagList = ArrayList<String>(savedTags.size)
        savedTags.forEach { tagList.add(it.tag) }
        return tagList
    }

    private fun saveTags() {
        val savedTagList = getSavedTagsList()
        NBSyncService.forceFeedsFolders()
        feedUtils.setStorySaved(story, true, requireContext(), savedTagList)
    }
}