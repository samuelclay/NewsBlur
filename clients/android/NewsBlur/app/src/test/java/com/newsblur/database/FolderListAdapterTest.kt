package com.newsblur.database

import com.newsblur.domain.Folder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FolderListAdapterTest {
    @Test
    fun safeFolderFeedIdsReturnsEmptySetForMissingFolder() {
        assertTrue(FolderListAdapter.safeFolderFeedIds(null).isEmpty())
    }

    @Test
    fun safeFolderFeedIdsReturnsEmptySetForFolderWithoutFeedIds() {
        assertTrue(FolderListAdapter.safeFolderFeedIds(Folder()).isEmpty())
    }

    @Test
    fun safeFolderFeedIdsCopiesExistingFeedIds() {
        val folder =
            Folder().apply {
                feedIds = listOf("1", "2")
            }

        assertEquals(setOf("1", "2"), FolderListAdapter.safeFolderFeedIds(folder))
    }
}
