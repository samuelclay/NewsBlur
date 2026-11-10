package com.newsblur.fragment

import android.content.Context
import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import com.newsblur.R
import com.newsblur.domain.PromptClassifierMatch

/**
 * "Content Filter: <prompt>" or "Image Filter: <prompt>" with a bold label, the way
 * media/js/newsblur/views/story_detail_view.js labels a matched AI prompt in the story header.
 */
internal fun aiFilterChipText(
    context: Context,
    match: PromptClassifierMatch,
): CharSequence {
    val label = context.getString(if (match.includeImages) R.string.ai_filter_image_label else R.string.ai_filter_content_label)
    val text = context.getString(R.string.ai_filter_chip, label, match.prompt.orEmpty())
    val start = text.indexOf(label)
    if (start < 0) return text
    return SpannableString(text).apply {
        setSpan(StyleSpan(Typeface.BOLD), start, start + label.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }
}
