package com.newsblur.fragment

import android.app.Dialog
import android.graphics.Typeface
import android.os.Bundle
import android.text.Spannable
import android.text.SpannableString
import android.text.style.AbsoluteSizeSpan
import android.text.style.StyleSpan
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.DialogFragment
import com.newsblur.R
import com.newsblur.databinding.StoryShortcutsDialogBinding

class StoryShortcutsFragment : DialogFragment() {

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val binding = StoryShortcutsDialogBinding.inflate(layoutInflater)

        SpannableString(getString(R.string.short_share_this_story_key)).apply {
            shiftKeySpannable()
        }.also {
            binding.txtShareStoryKey.text = it
        }

        SpannableString(getString(R.string.short_page_up_key)).apply {
            shiftKeySpannable()
        }.also {
            binding.txtPageUpKey.text = it
        }

        return AlertDialog.Builder(requireContext()).apply {
            setView(binding.root)
            setPositiveButton(android.R.string.ok, null)
        }.create()
    }

    private fun SpannableString.shiftKeySpannable() {
        setSpan(AbsoluteSizeSpan(18, true),
                0, 1, Spannable.SPAN_INCLUSIVE_INCLUSIVE)
        setSpan(StyleSpan(Typeface.BOLD),
                0, 1, Spannable.SPAN_INCLUSIVE_INCLUSIVE)
    }
}