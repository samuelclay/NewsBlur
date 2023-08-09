package com.newsblur.util

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.R
import com.newsblur.databinding.RowSavedTagBinding
import com.newsblur.domain.StarredCount

class TagsAdapter(private val type: Type,
                  private val listener: OnTagClickListener) : RecyclerView.Adapter<TagsAdapter.ViewHolder>() {

    private val tags = ArrayList<StarredCount>()

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.row_saved_tag, parent, false)
        return ViewHolder(view)
    }


    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val tag = tags[position]
        holder.binding.containerRow.setBackgroundResource(android.R.color.transparent)
        holder.binding.rowTagName.text = tag.tag
        holder.binding.rowSavedTagSum.text = tag.count.toString()
        holder.binding.root.setOnClickListener {
            listener.onTagClickListener(tag, type)
        }
    }

    override fun getItemCount(): Int = tags.size

    fun replaceAll(tags: MutableCollection<StarredCount>) {

        val diffCallback = TagDiffCallback(this.tags, tags.toList())
        val diffResult = DiffUtil.calculateDiff(diffCallback)
        this.tags.clear()
        this.tags.addAll(tags)
        diffResult.dispatchUpdatesTo(this)
    }

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val binding = RowSavedTagBinding.bind(view)
    }

    enum class Type {
        OTHER,
        SAVED
    }

    interface OnTagClickListener {
        fun onTagClickListener(starredTag: StarredCount, type: Type)
    }

    class TagDiffCallback(private val oldList: List<StarredCount>,
                          private val newList: List<StarredCount>) : DiffUtil.Callback() {

        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
                oldList[oldItemPosition].tag == newList[newItemPosition].tag &&
                        oldList[oldItemPosition].count == newList[newItemPosition].count

        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
                oldList[oldItemPosition].tag == newList[newItemPosition].tag &&
                        oldList[oldItemPosition].count == newList[newItemPosition].count

        override fun getOldListSize(): Int = oldList.size

        override fun getNewListSize(): Int = newList.size
    }
}