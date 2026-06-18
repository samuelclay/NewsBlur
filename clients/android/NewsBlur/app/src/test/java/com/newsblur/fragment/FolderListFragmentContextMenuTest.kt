package com.newsblur.fragment

import com.newsblur.R
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FolderListFragmentContextMenuTest {
    @Test
    fun folderMutingRequiresLiveFolderRow() {
        assertTrue(FolderListFragment.requiresLiveFolderContextMenuRow(R.id.menu_mute_folder))
        assertTrue(FolderListFragment.requiresLiveFolderContextMenuRow(R.id.menu_unmute_folder))
    }

    @Test
    fun folderEditingRequiresLiveFolderRow() {
        assertTrue(FolderListFragment.requiresLiveFolderContextMenuRow(R.id.menu_delete_folder))
        assertTrue(FolderListFragment.requiresLiveFolderContextMenuRow(R.id.menu_rename_folder))
    }

    @Test
    fun markingFolderReadCanAlsoApplyToAllStoriesRow() {
        assertFalse(FolderListFragment.requiresLiveFolderContextMenuRow(R.id.menu_mark_folder_as_read))
    }

    @Test
    fun feedActionsDoNotRequireFolderRow() {
        assertFalse(FolderListFragment.requiresLiveFolderContextMenuRow(R.id.menu_mute_feed))
        assertFalse(FolderListFragment.requiresLiveFolderContextMenuRow(R.id.menu_delete_feed))
    }
}
