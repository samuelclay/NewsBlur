package com.newsblur.onboarding

import com.newsblur.discover.DiscoveryFeed
import org.w3c.dom.Element
import java.io.ByteArrayInputStream
import javax.xml.parsers.DocumentBuilderFactory

// SetupOpml.kt validates locally before upload and preserves complete nested folder paths in the receipt.
object SetupOpml {
    const val MAX_BYTES = 10 * 1024 * 1024

    fun parse(data: ByteArray): Map<String, List<DiscoveryFeed>> {
        require(data.isNotEmpty() && data.size <= MAX_BYTES) { "Choose an OPML file smaller than 10 MB." }
        val factory =
            DocumentBuilderFactory.newInstance().apply {
                setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
                setFeature("http://xml.org/sax/features/external-general-entities", false)
                setFeature("http://xml.org/sax/features/external-parameter-entities", false)
                isExpandEntityReferences = false
            }
        val root = factory.newDocumentBuilder().parse(ByteArrayInputStream(data)).documentElement
        require(root.tagName.equals("opml", true)) { "This file is not an OPML feed list." }
        val folders = linkedMapOf<String, MutableList<DiscoveryFeed>>()

        fun visit(
            element: Element,
            path: List<String>,
        ) {
            var next = path
            if (element.tagName.equals("outline", true)) {
                val url = element.getAttribute("xmlUrl").ifBlank { element.getAttribute("xmlurl") }
                val title = element.getAttribute("title").ifBlank { element.getAttribute("text") }
                if (url.isNotBlank()) {
                    require(url.startsWith("https://") || url.startsWith("http://")) { "The OPML file contains an invalid feed address." }
                    folders.getOrPut(path.joinToString(" ▸ ")) { mutableListOf() }.add(DiscoveryFeed(url, title.ifBlank { url }))
                } else if (title.isNotBlank()) {
                    next = path + title
                }
            }
            for (i in 0 until element.childNodes.length) (element.childNodes.item(i) as? Element)?.let { visit(it, next) }
        }
        visit(root, emptyList())
        require(folders.isNotEmpty()) { "This OPML file contains no feeds." }
        return folders.mapValues { it.value.distinctBy { feed -> feed.url } }
    }
}
