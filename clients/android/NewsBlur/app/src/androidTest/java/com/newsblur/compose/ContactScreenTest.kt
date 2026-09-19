package com.newsblur.compose

import androidx.activity.ComponentActivity
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.newsblur.design.NbThemeVariant
import com.newsblur.design.NewsBlurTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ContactScreenTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun contactDetailsAndActionsAreAvailableInEveryTheme() {
        val theme = mutableStateOf(NbThemeVariant.Light)
        var emails = 0
        var websites = 0
        composeRule.setContent {
            NewsBlurTheme(variant = theme.value, dynamic = false) {
                ContactScreen(onBack = {}, onEmail = { emails++ }, onWebsite = { websites++ })
            }
        }
        val variants = listOf(NbThemeVariant.Light, NbThemeVariant.Dark, NbThemeVariant.Black, NbThemeVariant.Sepia)
        variants.forEach { variant ->
            composeRule.runOnIdle { theme.value = variant }
            composeRule.onNodeWithText("Contact us").assertIsDisplayed()
            composeRule.onNodeWithText("android@newsblur.com").performScrollTo().assertIsDisplayed()
            composeRule.onNodeWithText("Send email").performScrollTo().performClick()
            composeRule.onNodeWithText("https://www.newsblur.com").performScrollTo().assertIsDisplayed()
            composeRule.onNodeWithText("Visit website").performScrollTo().performClick()
        }
        composeRule.runOnIdle {
            assertEquals(variants.size, emails)
            assertEquals(variants.size, websites)
        }
    }
}
