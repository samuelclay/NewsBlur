package com.newsblur.fragment

import com.newsblur.domain.Folder
import com.newsblur.util.AppConstants
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// Test_AiClassifierFolderScope.kt: AiClassifierSections.kt disables the folder scope button when
// the trainer's feed has no folder path, so a top-level feed can't save a folder scope with an
// empty folder name, which apps/analyzer/views.py would store as a global prompt.
class Test_AiClassifierFolderScope {
    private fun folder(
        name: String,
        vararg feedIds: String,
        parents: List<String> = listOf(AppConstants.ROOT_FOLDER),
    ) = Folder().apply {
        this.name = name
        this.parents = parents
        this.feedIds = feedIds.toList()
    }

    private val folders =
        listOf(
            folder(AppConstants.ROOT_FOLDER, "1", "2", parents = emptyList()),
            folder("Blogs", "3"),
            folder("Tumblrs", "2", "4", parents = listOf(AppConstants.ROOT_FOLDER, "Blogs")),
        )

    @Test
    fun test_a_top_level_feed_has_no_folder_path() {
        assertNull(AiClassifierSections.folderPathOfFeed(folders, "1"))
    }

    @Test
    fun test_a_feed_in_a_folder_uses_the_flattened_folder_path() {
        assertEquals("Blogs", AiClassifierSections.folderPathOfFeed(folders, "3"))
        assertEquals("Blogs - Tumblrs", AiClassifierSections.folderPathOfFeed(folders, "4"))
        assertEquals(
            "A feed also at the top level still has its folder",
            "Blogs - Tumblrs",
            AiClassifierSections.folderPathOfFeed(folders, "2"),
        )
    }
}
