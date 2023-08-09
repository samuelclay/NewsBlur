package com.newsblur.benchmark

import androidx.benchmark.macro.ExperimentalBaselineProfilesApi
import androidx.benchmark.macro.junit4.BaselineProfileRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Runs in its own process
 */
@OptIn(ExperimentalBaselineProfilesApi::class)
@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {

    @get:Rule
    val rule = BaselineProfileRule()

    @Test
    fun generateSimpleStartupProfile() {
        rule.collectBaselineProfile(packageName = "com.newsblur") {
            pressHome()
            startActivityAndWait()
        }
    }

    @Test
    fun generateUserJourneyProfile() {
        var needsLogin = true
        rule.collectBaselineProfile(packageName = "com.newsblur") {
            pressHome()
            startActivityAndWait()

            if (needsLogin) {
                inputIntoLabel("username", "username")
                inputIntoLabel("password", "newsblur")
                clickOnText("LOGIN")
                needsLogin = false
                waitForTextShown("username")
            }

            waitLongForTextShown("All Stories")
            // switch to All view
            clickOnText("All")
            // wait for stories to load
            waitLongForTextShown("Android Developers Blog")
            // click on folder
            clickOnText("All Stories")
            // wait folder to load stories
            waitForTextShown("Electrek")

            device.pressBack()

            // wait for folder/feeds to load
            waitForTextShown("The NewsBlur Blog")
            // click on feed
            clickOnText("The NewsBlur Blog")
            // wait for some feed story to load
            waitForTextShown("Magazine view offers a new perspective")
        }
    }
}