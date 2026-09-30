package com.newsblur.activity

import android.content.res.ColorStateList
import android.os.Bundle
import androidx.activity.OnBackPressedCallback
import com.newsblur.databinding.ActivityReadingPlaceholderBinding
import dagger.hilt.android.AndroidEntryPoint

/**
 * Empty reader pane shown beside a story list in a tablet split view until a story is picked.
 * StorySplitView.kt launches it through a placeholder rule and replaces it with a Reading.kt
 * subclass as soon as a story is opened.
 */
@AndroidEntryPoint
class ReadingPlaceholder : NbActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val binding = ActivityReadingPlaceholderBinding.inflate(layoutInflater)
        setContentView(binding.root)
        // Tint the logo with the themed text color so it reads in light, sepia, dark, and black.
        binding.readingPlaceholderLogo.imageTintList = ColorStateList.valueOf(binding.readingPlaceholderText.currentTextColor)
        // Back reaches this pane, not the story list, because it is the split's right side. Finishing
        // here would take the story list with it (the placeholder rule in StorySplitView.kt) and
        // leave the app, so Back does what it does on the story list: slide the feed list over.
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    val storyList = ItemsList.peekReadingLaunchParent(taskId)?.takeIf { !it.isFinishing }
                    if (storyList != null) storyList.backToFeedList() else finish()
                }
            },
        )
    }

    // ReadingPlaceholder.kt shows no sync driven content.
    override fun handleUpdate(updateType: Int) = Unit
}
