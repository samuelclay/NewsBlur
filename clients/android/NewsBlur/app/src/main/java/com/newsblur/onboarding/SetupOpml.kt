package com.newsblur.onboarding

import com.newsblur.discover.DiscoveryFeed
import org.w3c.dom.Element
import java.io.ByteArrayInputStream
import javax.xml.parsers.DocumentBuilderFactory

// SetupOpml.kt validates locally before upload and preserves complete nested folder paths in the receipt.
object SetupOpml {
    const val MAX_BYTES = 10 * 1024 * 1024

    fun read(input: java.io.InputStream): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (true) {
            val count = input.read(buffer, 0, minOf(buffer.size, MAX_BYTES + 1 - out.size()))
            if (count < 0) break
            out.write(buffer, 0, count)
            require(out.size() <= MAX_BYTES) { "Choose an OPML file smaller than 10 MB." }
        }
        return out.toByteArray()
    }

    fun parse(data: ByteArray): Map<String, List<DiscoveryFeed>> {
        require(data.isNotEmpty() && data.size <= MAX_BYTES) { "Choose an OPML file smaller than 10 MB." }
        // SetupOpml.kt rejects declarations before parsing; Android's JAXP implementation lacks Xerces feature flags.
        val declarationText = data.toString(Charsets.ISO_8859_1).replace("\u0000", "")
        require(!Regex("<!\\s*(DOCTYPE|ENTITY)", RegexOption.IGNORE_CASE).containsMatchIn(declarationText)) {
            "OPML files cannot contain document types or external entities."
        }
        val builder = DocumentBuilderFactory.newInstance().newDocumentBuilder()
        builder.setEntityResolver { _, _ -> throw org.xml.sax.SAXException("External entities are not allowed.") }
        val document = builder.parse(ByteArrayInputStream(data))
        require(document.doctype == null) { "OPML files cannot contain document types." }
        val root = document.documentElement
        require(root.tagName.equals("opml", true)) { "This file is not an OPML feed list." }
        val folders = linkedMapOf<String, MutableList<DiscoveryFeed>>()
        var hasValidFeed = false
        // Match apps/feed_import/models.py INTERNAL_ADDRESS_PREFIXES; the backend may skip these feeds.
        val internalPrefixes = listOf("newsletter:", "http://newsletter:", "https://newsletter:", "webfeed:")

        fun visit(
            element: Element,
            path: List<String>,
            depth: Int = 0,
        ) {
            require(depth < 128) { "The OPML folder hierarchy is too deep." }
            var next = path
            if (element.tagName.equals("outline", true)) {
                val url = element.getAttribute("xmlUrl").ifBlank { element.getAttribute("xmlurl") }
                val title = element.getAttribute("title").ifBlank { element.getAttribute("text") }
                if (url.isNotBlank()) {
                    // SetupOpml.kt leaves internal NewsBlur addresses to the backend importer's ownership checks.
                    require(listOf("https://", "http://", "newsletter:", "webfeed:").any { url.startsWith(it) }) {
                        "The OPML file contains an invalid feed address."
                    }
                    hasValidFeed = true
                    if (internalPrefixes.none { url.startsWith(it) }) {
                        folders.getOrPut(path.joinToString(" ▸ ")) { mutableListOf() }.add(DiscoveryFeed(url, title.ifBlank { url }))
                    }
                } else if (title.isNotBlank()) {
                    next = path + title
                }
            }
            for (i in 0 until element.childNodes.length) (element.childNodes.item(i) as? Element)?.let { visit(it, next, depth + 1) }
        }
        visit(root, emptyList())
        require(hasValidFeed) { "This OPML file contains no feeds." }
        return folders.mapValues { it.value.distinctBy { feed -> feed.url } }
    }
}
