package com.newsblur.activity

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.text.TextUtils
import android.util.Base64
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.R
import com.newsblur.databinding.ViewFeedSearchRowBinding
import com.newsblur.domain.FeedResult

internal class FeedSearchAdapter(private val onClickListener: OnFeedSearchResultClickListener) : RecyclerView.Adapter<FeedSearchAdapter.ViewHolder>() {

    private val resultsList: MutableList<FeedResult> = ArrayList()

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.view_feed_search_row, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val result = resultsList[position]
        var bitmap: Bitmap? = null
        if (!TextUtils.isEmpty(result.favicon)) {
            val data = Base64.decode(result.favicon, Base64.DEFAULT)
            bitmap = BitmapFactory.decodeByteArray(data, 0, data.size)
        }
        bitmap?.let {
            holder.binding.imgFeedIcon.setImageBitmap(bitmap)
        }

        holder.binding.textTitle.text = result.label
        holder.binding.textTagline.text = result.tagline
        val subscribersCountText = holder.binding.root.context.resources.getString(R.string.feed_subscribers, result.numberOfSubscriber)
        holder.binding.textSubscriptionCount.text = subscribersCountText

        if (!TextUtils.isEmpty(result.url)) {
            holder.binding.rowResultAddress.text = result.url
            holder.binding.rowResultAddress.visibility = View.VISIBLE
        } else {
            holder.binding.rowResultAddress.visibility = View.GONE
        }

        holder.itemView.setOnClickListener {
            onClickListener.onFeedSearchResultClickListener(result)
        }
    }

    override fun getItemCount(): Int = resultsList.size

    fun replaceAll(results: Array<FeedResult>) {
        val newResultsList: List<FeedResult> = results.toList()
        val diffCallback = ResultDiffCallback(resultsList, newResultsList)
        val diffResult = DiffUtil.calculateDiff(diffCallback)
        resultsList.clear()
        resultsList.addAll(newResultsList)
        diffResult.dispatchUpdatesTo(this)
    }

    internal class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val binding: ViewFeedSearchRowBinding = ViewFeedSearchRowBinding.bind(itemView)
    }

    internal class ResultDiffCallback(private val oldList: List<FeedResult>,
                                      private val newList: List<FeedResult>) : DiffUtil.Callback() {

        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            val oldFeedResult = oldList[oldItemPosition]
            val newFeedResult = newList[newItemPosition]
            return oldFeedResult.label == newFeedResult.label &&
                    oldFeedResult.numberOfSubscriber == newFeedResult.numberOfSubscriber
        }

        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            val oldFeedResult = oldList[oldItemPosition]
            val newFeedResult = newList[newItemPosition]
            return oldFeedResult.label == newFeedResult.label
                    && oldFeedResult.tagline == newFeedResult.tagline
        }

        override fun getOldListSize(): Int = oldList.size

        override fun getNewListSize(): Int = newList.size
    }

    interface OnFeedSearchResultClickListener {

        fun onFeedSearchResultClickListener(result: FeedResult)
    }
}