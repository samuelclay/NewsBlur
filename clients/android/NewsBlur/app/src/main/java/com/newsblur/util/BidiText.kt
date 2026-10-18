package com.newsblur.util

/**
 * BidiText.kt keeps a run of user content, such as an author or a URL, in its own direction inside
 * interface text. An isolated run lays itself out on its own, so an English author inside an Arabic
 * line (or the reverse) can't drag the separators beside it to the wrong side. Android's first strong
 * text direction skips isolated runs, so a line holding only isolated content and punctuation, such
 * as "• author", takes the interface direction and keeps its bullet at the start.
 */
object BidiText {
    private const val LEFT_TO_RIGHT_ISOLATE = '⁦'
    private const val FIRST_STRONG_ISOLATE = '⁨'
    private const val POP_DIRECTIONAL_ISOLATE = '⁩'

    /** Isolates [text] in the direction of its own first strong character. */
    @JvmStatic
    fun isolate(text: String): String = "$FIRST_STRONG_ISOLATE$text$POP_DIRECTIONAL_ISOLATE"

    /** Isolates [text], such as a URL scheme, as left to right in any language. */
    @JvmStatic
    fun isolateLeftToRight(text: String): String = "$LEFT_TO_RIGHT_ISOLATE$text$POP_DIRECTIONAL_ISOLATE"
}
