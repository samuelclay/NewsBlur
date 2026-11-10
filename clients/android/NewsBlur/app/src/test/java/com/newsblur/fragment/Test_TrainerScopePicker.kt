package com.newsblur.fragment

import android.content.Context
import com.newsblur.domain.ClassifierScope
import com.newsblur.fragment.TrainerScopePicker.Denial
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_TrainerScopePicker.kt: every trainer capsule's scope toggles follow ScopeToggleView.swift.
// Folder and global need Premium Archive, and a top-level site can't take a folder scope, whose
// empty folder name apps/analyzer/views.py would store as a global classifier.
class Test_TrainerScopePicker {
    private fun picker(
        canUseWiderScopes: Boolean,
        folderPath: String?,
    ) = TrainerScopePicker(mockk<Context>(relaxed = true), canUseWiderScopes, folderPath)

    @Test
    fun test_site_scope_is_always_available() {
        assertEquals(ClassifierScope.FEED_SCOPE to null, picker(false, null).resolve(ClassifierScope.FEED))
    }

    @Test
    fun test_folder_and_global_need_premium_archive() {
        val picker = picker(false, "Tech")

        assertEquals(null to Denial.NEEDS_ARCHIVE, picker.resolve(ClassifierScope.FOLDER))
        assertEquals(null to Denial.NEEDS_ARCHIVE, picker.resolve(ClassifierScope.GLOBAL))
    }

    @Test
    fun test_folder_scope_uses_the_flattened_folder_path() {
        val picker = picker(true, "Tech - Apple")

        assertEquals(ClassifierScope.folder("Tech - Apple") to null, picker.resolve(ClassifierScope.FOLDER))
        assertEquals(ClassifierScope.GLOBAL_SCOPE to null, picker.resolve(ClassifierScope.GLOBAL))
        assertTrue(picker.isFolderAvailable)
    }

    @Test
    fun test_a_top_level_site_has_no_folder_scope() {
        val picker = picker(true, null)

        assertEquals(null to Denial.NO_FOLDER, picker.resolve(ClassifierScope.FOLDER))
        assertEquals(ClassifierScope.GLOBAL_SCOPE to null, picker.resolve(ClassifierScope.GLOBAL))
        assertFalse(picker.isFolderAvailable)
    }

    @Test
    fun test_kind_names_the_active_toggle() {
        assertEquals(ClassifierScope.FEED, TrainerScopePicker.kind(ClassifierScope.FEED_SCOPE))
        assertEquals(ClassifierScope.FOLDER, TrainerScopePicker.kind(ClassifierScope.folder("Tech")))
        assertEquals(ClassifierScope.GLOBAL, TrainerScopePicker.kind(ClassifierScope.GLOBAL_SCOPE))
    }
}
