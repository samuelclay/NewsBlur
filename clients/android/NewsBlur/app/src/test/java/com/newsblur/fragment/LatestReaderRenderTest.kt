package com.newsblur.fragment

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class LatestReaderRenderTest {
    @Test
    fun lateStoryPreparationCannotReplaceTheNewerTextDocument() =
        runTest {
            val renderer = LatestReaderRender<String, String>()
            val oldPreparation = CompletableDeferred<String>()
            val displayed = mutableListOf<String>()
            renderer.submit(this, "story", { withContext(NonCancellable) { oldPreparation.await() } }, displayed::add)
            runCurrent()
            renderer.submit(this, "text", { "text HTML" }, displayed::add)
            runCurrent()
            oldPreparation.complete("stale story HTML")
            runCurrent()
            assertEquals(listOf("text HTML"), displayed)
        }

    @Test
    fun repeatedPayloadsPrepareOnlyOnceEvenBeforeTheFirstPreparationCompletes() =
        runTest {
            val renderer = LatestReaderRender<String, String>()
            val prepared = CompletableDeferred<String>()
            var preparations = 0
            val displayed = mutableListOf<String>()
            repeat(3) {
                renderer.submit(this, "same", {
                    preparations++
                    prepared.await()
                }, displayed::add)
                runCurrent()
            }
            prepared.complete("HTML")
            runCurrent()
            renderer.submit(this, "same", {
                preparations++
                "HTML"
            }, displayed::add)
            runCurrent()
            assertEquals(1, preparations)
            assertEquals(listOf("HTML"), displayed)
        }

    @Test
    fun releasingAndRecreatingThePageInvalidatesPreparationAndAllowsTheSameDocumentAgain() =
        runTest {
            val renderer = LatestReaderRender<String, String>()
            val prepared = CompletableDeferred<String>()
            val displayed = mutableListOf<String>()
            renderer.submit(this, "same", { withContext(NonCancellable) { prepared.await() } }, displayed::add)
            runCurrent()
            renderer.clear()
            prepared.complete("old view")
            runCurrent()
            renderer.submit(this, "same", { "new view" }, displayed::add)
            runCurrent()
            assertEquals(listOf("new view"), displayed)
        }

    @Test
    fun reversingToTheAlreadyRenderedModeCancelsThePendingReplacement() =
        runTest {
            val renderer = LatestReaderRender<String, String>()
            val prepared = CompletableDeferred<String>()
            val displayed = mutableListOf<String>()
            renderer.submit(this, "story", { "story" }, displayed::add)
            runCurrent()
            renderer.submit(this, "text", { withContext(NonCancellable) { prepared.await() } }, displayed::add)
            runCurrent()
            renderer.submit(this, "story", { "unnecessary reload" }, displayed::add)
            prepared.complete("stale text")
            runCurrent()
            assertEquals(listOf("story"), displayed)
        }
}
