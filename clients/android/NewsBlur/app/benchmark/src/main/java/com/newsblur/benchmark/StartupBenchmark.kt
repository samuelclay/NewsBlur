package com.newsblur.benchmark

import androidx.benchmark.macro.*
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * This is a startup benchmark.
 *
 * It navigates to the device's home screen, and launches the default activity.
 *
 * Before running this benchmark:
 * 1) switch your app's active build variant in the Studio (affects Studio runs only)
 * 2) add `<profileable android:shell="true" />` to your app's manifest, within the `<application>` tag
 *
 * Run this benchmark from Studio to see startup measurements, and captured system traces
 * for investigating your app's performance.
 */

/**
 * Runs in its own process
 */
@OptIn(ExperimentalMetricApi::class)
@RunWith(AndroidJUnit4::class)
class StartupBenchmark {
    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    private val setupUsername = "android_speed"
    private val setupPass = "newsblur"
    private val packageName = "com.newsblur"
    private val iterations = 8
    private val measureStartupBlock: MacrobenchmarkScope.() -> Unit = {
        pressHome()
        startActivityAndWait()
        waitLongForTextShown("Android Authority")
        clickOnText("All Stories")
        waitForTextShown("All Stories")
    }

    /**
     * It resets the app compilation state and doesn't pre-compile the app.
     * Just in time compilation (JIT) is still enabled during execution of the app.
     */
    @Test
    fun startupColdCompilationNone() {
        var needsInitSetup = true
        benchmarkRule.measureRepeated(
                packageName = packageName,
                metrics = listOf(
                        StartupTimingMetric(),
                        TraceSectionMetric("MainOnCreate"),
                        TraceSectionMetric("ItemsListOnCreate"),
                ),
                iterations = iterations,
                startupMode = StartupMode.COLD,
                compilationMode = CompilationMode.None(),
                setupBlock = {
                    if (needsInitSetup) {
                        pressHome()
                        startActivityAndWait()

                        inputIntoLabel("username", setupUsername)
                        inputIntoLabel("password", setupPass)
                        needsInitSetup = false
                        clickOnText("LOGIN")
                        waitLongForTextShown("Android Authority")
                    }
                },
                measureBlock = measureStartupBlock,
        )
    }

    /**
     * It pre-compiles the app with Baseline Profiles and/or warm up runs.
     */
    @Test
    fun startupColdCompilationPartial() {
        var needsInitSetup = true
        benchmarkRule.measureRepeated(
                packageName = packageName,
                metrics = listOf(
                        StartupTimingMetric(),
                        TraceSectionMetric("MainOnCreate"),
                        TraceSectionMetric("ItemsListOnCreate"),
                ),
                iterations = iterations,
                startupMode = StartupMode.COLD,
                compilationMode = CompilationMode.Partial(),
                setupBlock = {
                    if (needsInitSetup) {
                        pressHome()
                        startActivityAndWait()

                        inputIntoLabel("username", setupUsername)
                        inputIntoLabel("password", setupPass)
                        needsInitSetup = false
                        clickOnText("LOGIN")
                        waitLongForTextShown("Android Authority")
                    }
                },
                measureBlock = measureStartupBlock,
        )
    }

    /**
     * It partially pre-compiles the app using Baseline Profiles if available
     */
    @Test
    fun startupColdCompilationDefault() {
        var needsInitSetup = true
        benchmarkRule.measureRepeated(
                packageName = packageName,
                metrics = listOf(
                        StartupTimingMetric(),
                        TraceSectionMetric("MainOnCreate"),
                        TraceSectionMetric("ItemsListOnCreate"),
                ),
                iterations = iterations,
                startupMode = StartupMode.COLD,
                compilationMode = CompilationMode.DEFAULT,
                setupBlock = {
                    if (needsInitSetup) {
                        pressHome()
                        startActivityAndWait()

                        inputIntoLabel("username", setupUsername)
                        inputIntoLabel("password", setupPass)
                        needsInitSetup = false
                        clickOnText("LOGIN")
                        waitLongForTextShown("Android Authority")
                    }
                },
                measureBlock = measureStartupBlock,
        )
    }

    /**
     * It pre-compiles the whole application code.
     * This is the only option on Android 6 (API 23) and lower.
     */
    @Test
    fun startupColdCompilationFull() {
        var needsInitSetup = true
        benchmarkRule.measureRepeated(
                packageName = packageName,
                metrics = listOf(
                        StartupTimingMetric(),
                        TraceSectionMetric("MainOnCreate"),
                        TraceSectionMetric("ItemsListOnCreate"),
                ),
                iterations = iterations,
                startupMode = StartupMode.COLD,
                compilationMode = CompilationMode.Full(),
                setupBlock = {
                    if (needsInitSetup) {
                        pressHome()
                        startActivityAndWait()

                        inputIntoLabel("username", setupUsername)
                        inputIntoLabel("password", setupPass)
                        needsInitSetup = false
                        clickOnText("LOGIN")
                        waitLongForTextShown("Android Authority")
                    }
                },
                measureBlock = measureStartupBlock,
        )
    }
}