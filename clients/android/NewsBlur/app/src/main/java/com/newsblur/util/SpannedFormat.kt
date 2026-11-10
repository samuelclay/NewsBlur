package com.newsblur.util

import android.text.SpannableStringBuilder
import android.text.Spanned

/**
 * SpannedFormat.kt fills a translated format string such as "%1$s subscribed to %2$s" and styles
 * each piece by what it is: every run of translated text gets one span, and each argument gets its
 * own. A translation can move the arguments anywhere, so callers never measure English fragments to
 * find where a username or story title landed. Only "%n$s", "%s" and "%%" are recognized, which
 * covers the activity strings in res/values/strings.xml.
 */
object SpannedFormat {
    /** The value for one placeholder, and a factory for the span that styles it (null leaves it plain). */
    class Argument(
        val text: String,
        val span: (() -> Any)?,
    )

    /** One run of the formatted text: template text when [argument] is null, otherwise that argument's value. */
    data class Piece(
        val text: String,
        val argument: Int?,
    )

    private val PLACEHOLDER = Regex("%(?:(\\d+)\\$)?s|%%")

    /**
     * Splits [template] into runs of template text and argument values, in display order. "%n$s"
     * takes the nth argument (1-based) and each "%s" takes the next one. A placeholder without a
     * matching argument stays as written.
     */
    @JvmStatic
    fun pieces(
        template: String,
        arguments: List<String>,
    ): List<Piece> {
        val pieces = mutableListOf<Piece>()
        val text = StringBuilder()
        var textStart = 0
        var nextSequential = 0
        for (match in PLACEHOLDER.findAll(template)) {
            text.append(template, textStart, match.range.first)
            textStart = match.range.last + 1
            if (match.value == "%%") {
                text.append('%')
                continue
            }
            val position = match.groupValues[1]
            val index = if (position.isEmpty()) nextSequential++ else position.toInt() - 1
            if (index in arguments.indices) {
                if (text.isNotEmpty()) pieces.add(Piece(text.toString(), null))
                text.setLength(0)
                pieces.add(Piece(arguments[index], index))
            } else {
                text.append(match.value)
            }
        }
        text.append(template, textStart, template.length)
        if (text.isNotEmpty()) pieces.add(Piece(text.toString(), null))
        return pieces
    }

    /**
     * Builds the styled text for [template]. [textSpan] makes a fresh span for each run of template
     * text, or is null to leave that text plain. Spans come from factories because one span object
     * can only cover a single range of a Spannable.
     */
    @JvmStatic
    fun format(
        template: String,
        textSpan: (() -> Any)?,
        vararg arguments: Argument,
    ): SpannableStringBuilder {
        val builder = SpannableStringBuilder()
        for (piece in pieces(template, arguments.map { it.text })) {
            val start = builder.length
            builder.append(piece.text)
            val span = if (piece.argument == null) textSpan else arguments[piece.argument].span
            // SpannedFormat.kt: an empty argument (a story without a title) has no range to style.
            if (span != null && builder.length > start) {
                builder.setSpan(span(), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }
        return builder
    }
}
