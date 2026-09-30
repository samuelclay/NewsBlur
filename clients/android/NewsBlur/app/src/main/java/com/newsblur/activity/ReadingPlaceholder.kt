package com.newsblur.activity

import android.content.res.ColorStateList
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.activity.OnBackPressedCallback
import com.newsblur.databinding.ActivityReadingPlaceholderBinding
import dagger.hilt.android.AndroidEntryPoint
import java.lang.ref.WeakReference

/**
 * Empty reader pane shown beside a story list in a tablet split view until a story is picked.
 * StorySplitView.kt launches it through a placeholder rule and replaces it with a Reading.kt
 * subclass as soon as a story is opened.
 */
@AndroidEntryPoint
class ReadingPlaceholder : NbActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(inflatePane(layoutInflater, null))
        showing = WeakReference(this)
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

    override fun onDestroy() {
        if (showing.get() === this) showing.clear()
        super.onDestroy()
    }

    // ReadingPlaceholder.kt shows no sync driven content.
    override fun handleUpdate(updateType: Int) = Unit

    companion object {
        private var showing = WeakReference<ReadingPlaceholder>(null)

        /** The empty reader pane beside the story list in [taskId], if that is what the pane shows. */
        @JvmStatic
        fun peek(taskId: Int): ReadingPlaceholder? = showing.get()?.takeIf { !it.isFinishing && !it.isDestroyed && it.taskId == taskId }

        /** The empty pane's view, also shown by a reader parked by a feed switch (Reading.fadeToPlaceholder). */
        fun inflatePane(
            inflater: LayoutInflater,
            parent: ViewGroup?,
        ): View {
            val binding = ActivityReadingPlaceholderBinding.inflate(inflater, parent, false)
            // Tint the logo with the themed text color so it reads in light, sepia, dark, and black.
            binding.readingPlaceholderLogo.imageTintList = ColorStateList.valueOf(binding.readingPlaceholderText.currentTextColor)
            return binding.root
        }
    }
}
