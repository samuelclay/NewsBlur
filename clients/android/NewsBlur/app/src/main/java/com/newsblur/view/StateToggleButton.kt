package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.LinearLayout
import com.newsblur.databinding.StateToggleBinding
import com.newsblur.util.StateFilter
import com.newsblur.util.UIUtils
import com.newsblur.util.setViewGone
import com.newsblur.util.setViewVisible


class StateToggleButton(context: Context, art: AttributeSet?) : LinearLayout(context, art) {

    private var state = StateFilter.SOME
    private var stateChangedListener: StateChangedListener? = null
    private val binding: StateToggleBinding

    init {
        binding = StateToggleBinding.inflate(LayoutInflater.from(context), this, true)
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

        val widthDp = UIUtils.px2dp(context, context.resources.displayMetrics.widthPixels)
        if (widthDp > 450) {
            binding.toggleSomeText.setViewVisible()
            binding.toggleFocusText.setViewVisible()
            binding.toggleSavedText.setViewVisible()
        } else if (widthDp > 400) {
            binding.toggleSomeText.setViewVisible()
            binding.toggleFocusText.setViewVisible()
            binding.toggleSavedText.setViewGone()
        } else if (widthDp > 350) {
            binding.toggleSomeText.setViewVisible()
            binding.toggleFocusText.setViewGone()
            binding.toggleSavedText.setViewGone()
        } else {
            binding.toggleSomeText.setViewGone()
            binding.toggleFocusText.setViewGone()
            binding.toggleSavedText.setViewGone()
        }
    }

    interface StateChangedListener {
        fun changedState(state: StateFilter?)
    }
}