package com.newsblur.listen

/**
 * ListenParagraphMatcher.kt pairs the manifest's paragraphs with the text blocks listenFollowAlong.js found in
 * the rendered story. Following the shared Listen contract, each paragraph is matched by its first 40
 * whitespace-collapsed characters, scanning forward in document order; anything unmatched just isn't highlighted.
 */
object ListenParagraphMatcher {
    const val MATCH_LENGTH = 40

    // Smart quotes, dashes and stray punctuation differ between extracted text and the rendered HTML.
    private const val LOOSE_MATCH_LENGTH = 28
    private const val LOOSE_MIN_LENGTH = 12

    private val whitespace = Regex("[\\s\\u00A0\\u2007\\u202F]+")
    private val nonWordCharacters = Regex("[^\\p{L}\\p{N}]+")

    fun normalize(text: String?): String = text.orEmpty().replace(whitespace, " ").trim()

    fun key(text: String?): String = normalize(text).take(MATCH_LENGTH).lowercase()

    private fun looseKey(text: String?): String =
        normalize(text)
            .lowercase()
            .replace(nonWordCharacters, "")
            .take(LOOSE_MATCH_LENGTH)

    /**
     * Returns block index to paragraph index. The title paragraph is left out because the title is drawn
     * natively above the WebView (ReadingItemFragment.kt highlights it separately).
     */
    fun match(
        paragraphs: List<ListenParagraph>,
        blockTexts: List<String>,
    ): Map<Int, Int> {
        val blockKeys = blockTexts.map(::key)
        val blockLooseKeys = blockTexts.map(::looseKey)
        val matches = linkedMapOf<Int, Int>()
        var cursor = 0
        for (paragraph in paragraphs) {
            if (paragraph.isTitle) continue
            val paragraphKey = key(paragraph.text)
            if (paragraphKey.isEmpty()) continue
            var found = (cursor until blockKeys.size).firstOrNull { blockKeys[it] == paragraphKey }
            if (found == null) {
                val paragraphLoose = looseKey(paragraph.text)
                if (paragraphLoose.length >= LOOSE_MIN_LENGTH) {
                    found =
                        (cursor until blockLooseKeys.size).firstOrNull {
                            blockLooseKeys[it] == paragraphLoose
                        }
                }
            }
            if (found != null) {
                matches[found] = paragraph.index
                cursor = found + 1
            }
        }
        return matches
    }

    /** The blocks to highlight for a segment's paragraphs. */
    fun blocksFor(
        paragraphIndexes: Collection<Int>,
        blockToParagraph: Map<Int, Int>,
    ): List<Int> = blockToParagraph.filterValues { it in paragraphIndexes }.keys.sorted()
}
