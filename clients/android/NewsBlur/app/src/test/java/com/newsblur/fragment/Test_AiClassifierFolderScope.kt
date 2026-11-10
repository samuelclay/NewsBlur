package com.newsblur.fragment

import com.newsblur.domain.ClassifierScope
import com.newsblur.domain.Folder
import com.newsblur.util.AppConstants
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// Test_AiClassifierFolderScope.kt: TrainerScopePicker.kt refuses the folder scope when the
// trainer's feed has no folder path, so a top-level feed can't save a folder scope with an empty
// folder name, which apps/analyzer/views.py would store as a global classifier. A nested folder
// is saved and estimated (AiClassifierCost.kt) by the same full flatten_folders path.
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
        assertNull(TrainerScopePicker.folderPathOfFeed(folders, "1"))
    }

    @Test
    fun test_a_feed_in_a_folder_uses_the_flattened_folder_path() {
        assertEquals("Blogs", TrainerScopePicker.folderPathOfFeed(folders, "3"))
        assertEquals("Blogs - Tumblrs", TrainerScopePicker.folderPathOfFeed(folders, "4"))
        assertEquals(
            "A feed also at the top level still has its folder",
            "Blogs - Tumblrs",
            TrainerScopePicker.folderPathOfFeed(folders, "2"),
        )
    }

    @Test
    fun test_a_nested_folder_scope_estimates_the_stories_at_its_full_path() {
        // Two folders named Swift: only the one the scope's full path names counts.
        val nested =
            listOf(
                folder(AppConstants.ROOT_FOLDER, "1", parents = emptyList()),
                folder("Tech", "10"),
                folder("Swift", "11", "12", parents = listOf(AppConstants.ROOT_FOLDER, "Tech")),
                folder("Birds", "20"),
                folder("Swift", "21", parents = listOf(AppConstants.ROOT_FOLDER, "Birds")),
            )
        val storiesByFeed = mapOf("1" to 1, "10" to 10, "11" to 110, "12" to 120, "20" to 200, "21" to 2100)

        // The scope the trainer saves for a site in Tech > Swift, as apps/reader/models.py flatten_folders names it.
        val path = TrainerScopePicker.folderPathOfFeed(nested, "11")
        assertEquals("Tech - Swift", path)
        assertEquals(110 + 120, AiClassifierCost.storiesForScope(ClassifierScope.folder(path!!), 110, nested, storiesByFeed))
        assertEquals(2100, AiClassifierCost.storiesForScope(ClassifierScope.folder("Birds - Swift"), 0, nested, storiesByFeed))
        assertEquals(
            "A leaf name alone is not a nested folder's path",
            0,
            AiClassifierCost.storiesForScope(ClassifierScope.folder("Swift"), 0, nested, storiesByFeed),
        )
    }
}
