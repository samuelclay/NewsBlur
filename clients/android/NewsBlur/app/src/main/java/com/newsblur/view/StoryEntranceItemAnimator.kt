package com.newsblur.view

import androidx.recyclerview.widget.DefaultItemAnimator
import androidx.recyclerview.widget.RecyclerView

/** StoryEntranceItemAnimator.kt leaves first-visible entrances to ReaderMotion while retaining list rearrangements. */
class StoryEntranceItemAnimator : DefaultItemAnimator() {
    override fun animateAdd(holder: RecyclerView.ViewHolder): Boolean {
        // StoryEntranceItemAnimator.kt must not hide titles while DefaultItemAnimator waits for the loading footer to move.
        endAnimation(holder)
        holder.itemView.alpha = 1f
        dispatchAddFinished(holder)
        return false
    }
}
