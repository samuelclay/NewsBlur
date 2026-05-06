package com.newsblur.activity

import android.content.ComponentCallbacks2
import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingMemoryTrimTest {
    @Test
    fun releasesOnlyBackgroundReaderWebViewsWhenUiIsHidden() {
        assertEquals(
            ReaderWebViewReleaseScope.BACKGROUND_ONLY,
            readerWebViewReleaseScopeForTrim(
                level = ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN,
                isChangingConfigurations = false,
            ),
        )
    }

    @Test
    fun releasesAllReaderWebViewsUnderBackgroundMemoryPressure() {
        assertEquals(
            ReaderWebViewReleaseScope.ALL,
            readerWebViewReleaseScopeForTrim(
                level = ComponentCallbacks2.TRIM_MEMORY_BACKGROUND,
                isChangingConfigurations = false,
            ),
        )
    }

    @Test
    fun ignoresForegroundTrimSignals() {
        assertEquals(
            ReaderWebViewReleaseScope.NONE,
            readerWebViewReleaseScopeForTrim(
                level = ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW,
                isChangingConfigurations = false,
            ),
        )
    }

    @Test
    fun ignoresConfigurationChanges() {
        assertEquals(
            ReaderWebViewReleaseScope.NONE,
            readerWebViewReleaseScopeForTrim(
                level = ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN,
                isChangingConfigurations = true,
            ),
        )
    }
}
