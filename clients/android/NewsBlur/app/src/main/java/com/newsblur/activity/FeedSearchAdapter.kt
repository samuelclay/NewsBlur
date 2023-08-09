package com.newsblur.activity

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.R
import com.newsblur.databinding.ViewFeedSearchRowBinding
import com.newsblur.domain.FeedResult
import com.newsblur.util.ImageLoader
import com.newsblur.util.setViewGone
import com.newsblur.util.setViewVisible

class FeedSearchAdapter(
        private val onClickListener: OnFeedSearchResultClickListener,
        private val iconLoader: ImageLoader
) : RecyclerView.Adapter<FeedSearchAdapter.ViewHolder>() {

    private val resultsList: MutableList<FeedResult> = mutableListOf()

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.view_feed_search_row, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val result = resultsList[position]
        holder.bind(result)
    }

    override fun getItemCount(): Int = resultsList.size

    fun replaceAll(results: List<FeedResult>) {
        val diffCallback = ResultDiffCallback(resultsList, results)
        val diffResult = DiffUtil.calculateDiff(diffCallback)
        resultsList.clear()
        resultsList.addAll(results)
        diffResult.dispatchUpdatesTo(this)
    }

    inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {

        private val binding: ViewFeedSearchRowBinding = ViewFeedSearchRowBinding.bind(itemView)

        fun bind(result: FeedResult) {
            val resultFaviconUrl = result.faviconUrl
            if (resultFaviconUrl.isNotEmpty()) {
                iconLoader.displayImage(resultFaviconUrl, binding.imgFeedIcon)
            }

            binding.textTitle.text = result.label
            binding.textTagline.text = result.tagline

            if (result.numberOfSubscriber > 0) {
                val subscribersCountText = binding.root.context.getString(R.string.feed_subscribers, result.numberOfSubscriber)
                binding.textSubscriptionCount.text = subscribersCountText
                binding.textSubscriptionCount.setViewVisible()
            } else {
                binding.textSubscriptionCount.setViewGone()
            }

            if (result.url.isNotEmpty()) {
                binding.rowResultAddress.text = result.url
                binding.rowResultAddress.setViewVisible()
            } else {
                binding.rowResultAddress.setViewGone()
            }

            itemView.setOnClickListener {
                onClickListener.onFeedSearchResultClickListener(result)
            }
        }
    }

    class ResultDiffCallback(
            private val oldList: List<FeedResult>,
            private val newList: List<FeedResult>) : DiffUtil.Callback() {

        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            val oldFeedResult = oldList[oldItemPosition]
            val newFeedResult = newList[newItemPosition]
            return oldFeedResult == newFeedResult
        }

        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            val oldFeedResult = oldList[oldItemPosition]
            val newFeedResult = newList[newItemPosition]
            return oldFeedResult.id == newFeedResult.id
                    && oldFeedResult.label == newFeedResult.label
        }

        override fun getOldListSize(): Int = oldList.size

        override fun getNewListSize(): Int = newList.size
    }

    interface OnFeedSearchResultClickListener {

        fun onFeedSearchResultClickListener(result: FeedResult)
    }
}