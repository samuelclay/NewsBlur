package com.newsblur.util

import android.content.Context
import android.view.ContextThemeWrapper
import android.view.Gravity
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TryFeedBannerStyleTest {
    @Test
    fun subscribe_button_style_centers_text_without_font_padding() {
        val baseContext = ApplicationProvider.getApplicationContext<Context>()
        val themedContext = ContextThemeWrapper(baseContext, R.style.NewsBlurTheme)
        val styledContext = ContextThemeWrapper(themedContext, R.style.tryFeedBannerSubscribeButton)
        val button = MaterialButton(styledContext)

        assertEquals(Gravity.CENTER, button.gravity)
    }
}
