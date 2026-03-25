package com.newsblur.activity

import android.content.ComponentName
import android.content.pm.ActivityInfo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LoginActivityConfigTest {
    @Test
    fun loginActivity_keepsHistorySoCredentialsSurviveAppSwitches() {
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        @Suppress("DEPRECATION")
        val activityInfo =
            appContext.packageManager.getActivityInfo(
                ComponentName(appContext, LoginActivity::class.java),
                0,
            )

        assertEquals(0, activityInfo.flags and ActivityInfo.FLAG_NO_HISTORY)
    }
}
