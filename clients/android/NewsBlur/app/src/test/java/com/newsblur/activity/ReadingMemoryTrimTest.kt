package com.newsblur.activity

import android.content.ComponentCallbacks2
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReadingMemoryTrimTest {
    @Test
    fun releasesReaderWebViewsWhenUiIsHidden() {
        assertTrue(
            shouldReleaseReaderWebViewsOnTrim(
                level = ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN,
                isChangingConfigurations = false,
            ),
        )
    }

    @Test
    fun ignoresForegroundTrimSignals() {
        assertFalse(
            shouldReleaseReaderWebViewsOnTrim(
                level = ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW,
                isChangingConfigurations = false,
            ),
        )
    }

    @Test
    fun ignoresConfigurationChanges() {
        assertFalse(
            shouldReleaseReaderWebViewsOnTrim(
                level = ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN,
                isChangingConfigurations = true,
            ),
        )
    }
}
