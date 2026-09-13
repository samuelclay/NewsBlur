package com.newsblur.domain

import com.google.gson.Gson
import com.newsblur.network.domain.FeedFolderResponse
import com.newsblur.util.AppConstants
import org.junit.Assert.*
import org.junit.Test

class FolderHierarchyTest {
    private fun response() = FeedFolderResponse(
        """{"authenticated":true,"folders":[99,{"Blogs":[1,{"Links":[2,{"People":[3,1]}]}]},{"Art":[{"Links":[4]}]},{"Blogspot":[5]},{"Empty":[]}],"feeds":{}}""",
        Gson(),
    )

    @Test fun parserRetainsDuplicateLeafNamesAndEveryDepth() {
        val folders = response().folders.associateBy { it.flatName() }
        assertEquals(8, folders.size)
        assertEquals(listOf("2"), folders.getValue("Blogs ▸ Links").feedIds)
        assertEquals(listOf("4"), folders.getValue("Art ▸ Links").feedIds)
        assertEquals(2, folders.getValue("Blogs ▸ Links ▸ People").depth())
        assertEquals("Links", folders.getValue("Blogs ▸ Links ▸ People").firstParentName)
    }

    @Test fun preorderKeepsChildrenWithTheirParentAndEmptyFoldersInPickers() {
        assertEquals(listOf(AppConstants.ROOT_FOLDER, "Art", "Art ▸ Links", "Blogs", "Blogs ▸ Links",
            "Blogs ▸ Links ▸ People", "Blogspot", "Empty"), FolderHierarchy(response().folders).ordered.map { it.flatName() })
    }

    @Test fun descendantsKeepTheirEmptyAncestorsVisibleAndCountsDeduplicateFeeds() {
        val tree = FolderHierarchy(response().folders)
        assertEquals(setOf("1", "2", "3"), tree.feedIds("Blogs"))
        assertEquals(listOf(AppConstants.ROOT_FOLDER, "Art", "Art ▸ Links"),
            tree.visibleFolders(setOf("Art ▸ Links"), emptySet()).map { it.flatName() })
    }

    @Test fun collapsingAParentPreservesChildStateWithoutAffectingSameNamedSiblings() {
        val tree = FolderHierarchy(response().folders)
        val all = tree.ordered.map { it.flatName() }.toSet()
        val closed = mutableSetOf("Blogs", "Blogs ▸ Links")
        assertFalse(tree.visibleFolders(all, closed).any { it.flatName() == "Blogs ▸ Links" })
        assertTrue(tree.visibleFolders(all, closed).any { it.flatName() == "Art ▸ Links" })
        closed.remove("Blogs")
        assertTrue(tree.visibleFolders(all, closed).any { it.flatName() == "Blogs ▸ Links" })
        assertFalse(tree.visibleFolders(all, closed).any { it.name == "People" })
    }
}
