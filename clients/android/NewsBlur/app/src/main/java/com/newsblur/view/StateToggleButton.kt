package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import com.newsblur.R
import com.newsblur.databinding.StateToggleBinding
import com.newsblur.util.StateFilter
import com.newsblur.util.UIUtils

class StateToggleButton(
    context: Context,
    art: AttributeSet?,
) : LinearLayout(context, art) {
    private var state = StateFilter.SOME
    private var stateChangedListener: StateChangedListener? = null
    private val binding: StateToggleBinding

    init {
        binding = StateToggleBinding.inflate(LayoutInflater.from(context), this, true)
        listOf(
            binding.toggleAll to R.string.state_all,
            binding.toggleSome to R.string.state_unread,
            binding.toggleFocus to R.string.state_focus,
            binding.toggleSaved to R.string.state_saved,
        ).forEach { (view, label) ->
            view.contentDescription = context.getString(label)
            view.minimumHeight = UIUtils.dp2px(context, 36)
            view.minimumWidth = UIUtils.dp2px(context, 40)
        }
        setState(state)
        binding.toggleAll.setOnClickListener { setState(StateFilter.ALL) }
        binding.toggleSome.setOnClickListener { setState(StateFilter.SOME) }
        binding.toggleFocus.setOnClickListener { setState(StateFilter.BEST) }
        binding.toggleSaved.setOnClickListener { setState(StateFilter.SAVED) }
    }

    fun setStateListener(stateChangedListener: StateChangedListener?) {
        this.stateChangedListener = stateChangedListener
    }

    fun setState(state: StateFilter) {
        this.state = state
        updateButtonStates()
        stateChangedListener?.changedState(this.state)
    }

    private fun updateButtonStates() {
        binding.toggleAll.isEnabled = state != StateFilter.ALL
        binding.toggleSome.isEnabled = state != StateFilter.SOME
        binding.toggleSomeIcon.alpha = if (state == StateFilter.SOME) 1.0f else 0.6f
        binding.toggleFocus.isEnabled = state != StateFilter.BEST
        binding.toggleFocusIcon.alpha = if (state == StateFilter.BEST) 1.0f else 0.6f
        binding.toggleSaved.isEnabled = state != StateFilter.SAVED
        binding.toggleSavedIcon.alpha = if (state == StateFilter.SAVED) 1.0f else 0.6f
    }

    override fun onMeasure(
        widthMeasureSpec: Int,
        heightMeasureSpec: Int,
    ) {
        // StateToggleButton.kt measures the actual capsule space, including large text and split-screen widths.
        val labels = listOf(binding.toggleSomeText, binding.toggleFocusText, binding.toggleSavedText)
        labels.forEach { it.visibility = View.VISIBLE }
        binding.root.measure(MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED), heightMeasureSpec)
        val available = MeasureSpec.getSize(widthMeasureSpec)
        if (MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED && binding.root.measuredWidth > available) {
            labels.forEach { it.visibility = View.GONE }
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    interface StateChangedListener {
        fun changedState(state: StateFilter?)
    }
}
