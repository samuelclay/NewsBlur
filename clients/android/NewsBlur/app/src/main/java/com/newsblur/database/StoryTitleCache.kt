package com.newsblur.database

internal class StoryTitleCache(
    private val maxCharacters: Int = 64 * 1024,
    private val parse: (String) -> CharSequence,
) {
    private val titles = LinkedHashMap<String, CharSequence>(16, 0.75f, true)
    private var characters = 0

    fun get(html: String?): CharSequence {
        val source = html.orEmpty()
        titles[source]?.let { return it }
        val title = parse(source)
        val size = source.length + title.length + 1
        if (size > maxCharacters) return title

        titles[source] = title
        characters += size
        val iterator = titles.entries.iterator()
        while (characters > maxCharacters && iterator.hasNext()) {
            val entry = iterator.next()
            characters -= entry.key.length + entry.value.length + 1
            iterator.remove()
        }
        return title
    }

    fun clear() {
        titles.clear()
        characters = 0
    }
}
