package com.newsblur.util

/**
 * StoryButtons.kt lists the buttons under a story in reading_item_actions.xml. Each one can be hidden
 * from Settings, and the choice syncs with the web and iOS through the server's show_sideoption prefs.
 */
enum class StoryButton(
    val prefKey: String,
) {
    TRAIN("show_sideoption_train"),
    SAVE("show_sideoption_save"),
    SHARE("show_sideoption_share"),
    ASK_AI("show_sideoption_ask_ai"),
    LISTEN("show_sideoption_listen"),
    ;

    companion object {
        val prefKeys: Set<String> = entries.map { it.prefKey }.toSet()

        fun forPrefKey(key: String): StoryButton? = entries.firstOrNull { it.prefKey == key }
    }
}

object StoryButtonLayout {
    /** Five buttons can't fit one phone-width row, so StoryButtons.kt splits them three over two. */
    private const val SPLIT_COUNT = 5
    private const val FIRST_ROW_WHEN_SPLIT = 3

    fun <T> rows(visible: List<T>): List<List<T>> =
        when {
            visible.isEmpty() -> emptyList()
            visible.size >= SPLIT_COUNT ->
                listOf(
                    visible.take(FIRST_ROW_WHEN_SPLIT),
                    visible.drop(FIRST_ROW_WHEN_SPLIT),
                )
            else -> listOf(visible)
        }
}
