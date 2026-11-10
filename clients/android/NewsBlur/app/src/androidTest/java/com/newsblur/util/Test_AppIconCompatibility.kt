package com.newsblur.util

import android.content.Context
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@Suppress("ktlint:standard:class-naming")
class Test_AppIconCompatibility {
    @Test
    fun test_preferences_icon_selection_resolves_on_supported_android_versions() {
        val context = ApplicationProvider.getApplicationContext<Context>()

        // SettingsScreen.kt reads this before showing Preferences, including on Android 8 through 11.
        val selection = AppIconManager.currentSelection(context)
        val component = AppIconManager.componentName(context, selection.flavor, selection.mode)

        assertEquals(context.packageName, component.packageName)
        assertNotNull(context.packageManager.getActivityInfo(component, PackageManager.MATCH_DISABLED_COMPONENTS))
    }

    @Test
    fun test_icon_components_resolve_for_all_flavors_and_appearances() {
        val context = ApplicationProvider.getApplicationContext<Context>()

        AppIconManager.flavors.forEach { flavor ->
            AppIconAppearanceMode.entries.forEach { mode ->
                val component = AppIconManager.componentName(context, flavor, mode)
                val activity = context.packageManager.getActivityInfo(component, PackageManager.MATCH_DISABLED_COMPONENTS)

                assertEquals(context.packageName, component.packageName)
                assertEquals("com.newsblur.activity.InitActivity", activity.targetActivity)
            }
        }
    }
}
