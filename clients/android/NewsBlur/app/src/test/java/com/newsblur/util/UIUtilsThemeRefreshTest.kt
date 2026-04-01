package com.newsblur.util

import android.app.Activity
import android.content.Intent
import io.mockk.mockk
import io.mockk.verify
import org.junit.Test

class UIUtilsThemeRefreshTest {
    @Test
    fun restartActivity_recreates_in_place_instead_of_relaunching() {
        val activity = mockk<Activity>(relaxed = true)

        UIUtils.restartActivity(activity)

        verify(exactly = 1) { activity.recreate() }
        verify(exactly = 0) { activity.finish() }
        verify(exactly = 0) { activity.startActivity(any<Intent>()) }
    }
}
