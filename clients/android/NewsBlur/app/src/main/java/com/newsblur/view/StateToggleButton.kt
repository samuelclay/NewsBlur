package com.newsblur.view

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
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
        requestLayout()
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
        val labels =
            listOf(
                binding.toggleSomeText to StateFilter.SOME,
                binding.toggleFocusText to StateFilter.BEST,
                binding.toggleSavedText to StateFilter.SAVED,
            )
        val naturalWidth =
            listOf(binding.toggleAll, binding.toggleSome, binding.toggleFocus, binding.toggleSaved).sumOf { button ->
                val contentWidth =
                    (0 until button.childCount).sumOf { index ->
                        val child = button.getChildAt(index)
                        val margins = child.layoutParams as ViewGroup.MarginLayoutParams
                        // StateToggleButton.kt respects the XML icon size instead of its drawable's intrinsic width.
                        val childWidthSpec =
                            if (margins.width >= 0) {
                                MeasureSpec.makeMeasureSpec(margins.width, MeasureSpec.EXACTLY)
                            } else {
                                MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
                            }
                        child.measure(childWidthSpec, heightMeasureSpec)
                        child.measuredWidth + margins.leftMargin + margins.rightMargin
                    }
                val margins = button.layoutParams as ViewGroup.MarginLayoutParams
                val buttonWidth = maxOf(button.minimumWidth, contentWidth + button.paddingLeft + button.paddingRight)
                buttonWidth + margins.leftMargin + margins.rightMargin
            }
        val available = MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight
        val compact =
            MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED &&
                naturalWidth > available
        // StateToggleButton.kt measures hidden labels directly to avoid toggling layout animations on every pass.
        labels.forEach { (label, filter) ->
            val visibility = if (!compact || state == filter) View.VISIBLE else View.GONE
            if (label.visibility != visibility) label.visibility = visibility
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    interface StateChangedListener {
        fun changedState(state: StateFilter?)
    }
}
