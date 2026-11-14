package com.newsblur.addsite

import androidx.lifecycle.SavedStateHandle
import com.newsblur.MainDispatcherRule
import com.newsblur.domain.Feed
import com.newsblur.domain.FeedResult
import com.newsblur.network.FeedApi
import com.newsblur.network.FolderApi
import com.newsblur.network.FolderPath
import com.newsblur.network.domain.AddFeedResponse
import com.newsblur.network.domain.NewsBlurResponse
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AddSiteViewModelTest {
    @get:Rule val main = MainDispatcherRule()
    private val feedApi = mockk<FeedApi>()
    private val folderApi = mockk<FolderApi>()

    @After fun resetFolderMetadata() {
        FolderPath.setFolders(emptyList())
    }

    private fun model(saved: SavedStateHandle = SavedStateHandle()) =
        AddSiteViewModel(feedApi, folderApi, saved).apply { workerDispatcher = main.dispatcher }

    @Test fun typingDebouncesAndClearingInvalidatesInFlightResults() =
        runTest {
            val pending = CompletableDeferred<Array<FeedResult>>()
            coEvery { feedApi.searchForFeed("kottke") } coAnswers { withContext(NonCancellable) { pending.await() } }
            val model = model()
            model.queryChanged("kot")
            advanceTimeBy(200)
            model.queryChanged("kottke")
            advanceTimeBy(350)
            runCurrent()
            coVerify(exactly = 0) { feedApi.searchForFeed("kot") }
            model.queryChanged("")
            pending.complete(arrayOf(FeedResult(label = "kottke.org", url = "https://kottke.org")))
            advanceUntilIdle()
            assertTrue(
                model.state.value.results
                    .isEmpty(),
            )
            assertFalse(model.state.value.searching)
            assertFalse(model.state.value.searched)
        }

    @Test fun olderSearchCannotReplaceNewerSearch() =
        runTest {
            val old = CompletableDeferred<Array<FeedResult>>()
            val new = FeedResult(label = "NewsBlur", url = "https://newsblur.com")
            coEvery { feedApi.searchForFeed("old") } coAnswers { withContext(NonCancellable) { old.await() } }
            coEvery { feedApi.searchForFeed("new") } returns arrayOf(new)
            val model = model()
            model.queryChanged("old")
            advanceTimeBy(350)
            runCurrent()
            model.queryChanged("new")
            advanceTimeBy(350)
            runCurrent()
            old.complete(arrayOf(FeedResult(label = "Old", url = "https://old.example")))
            advanceUntilIdle()
            assertEquals(listOf(new), model.state.value.results)
        }

    @Test fun retryUsesCreatedFolderWithoutCreatingItAgain() =
        runTest {
            coEvery { folderApi.addFolder("Friends", "Blogs ▸ Link Blogs") } returns NewsBlurResponse()
            coEvery { feedApi.addFeed("https://example.com", "Blogs ▸ Link Blogs ▸ Friends") } returnsMany
                listOf(
                    AddFeedResponse().apply {
                        code = -1
                        message = "Offline"
                    },
                    AddFeedResponse().apply { feed = Feed().apply { feedId = "42" } },
                )
            val saved = SavedStateHandle()
            val model = model(saved)
            model.chooseFolder("Blogs ▸ Link Blogs")
            model.toggleNewFolder()
            model.folderNameChanged("Friends")
            model.submit("https://example.com")
            advanceUntilIdle()
            assertEquals("Offline", model.state.value.error)
            assertEquals("Blogs ▸ Link Blogs ▸ Friends", model.state.value.parent)
            assertFalse(model.state.value.creatingFolder)
            assertEquals("Blogs ▸ Link Blogs ▸ Friends", saved.get<String>("parent"))
            model.submit()
            advanceUntilIdle()
            coVerify(exactly = 1) { folderApi.addFolder(any(), any()) }
            assertEquals("42", model.state.value.completedFeedId)
        }

    @Test fun repeatedTapCannotSubmitTwiceAndFolderErrorsDoNotAddFeed() =
        runTest {
            val pending = CompletableDeferred<NewsBlurResponse>()
            coEvery { folderApi.addFolder("Friends", any()) } coAnswers { pending.await() }
            val model = model()
            model.toggleNewFolder()
            model.folderNameChanged("Friends")
            model.submit("https://example.com")
            model.submit("https://example.com")
            runCurrent()
            pending.complete(
                NewsBlurResponse().apply {
                    code = -1
                    message = "Folder already exists"
                },
            )
            advanceUntilIdle()
            coVerify(exactly = 1) { folderApi.addFolder(any(), any()) }
            coVerify(exactly = 0) { feedApi.addFeed(any(), any()) }
            assertNotNull(model.state.value.error)
            assertFalse(model.state.value.submitting)
        }

    @Test fun folderOnlyCreationDoesNotSubscribeToAnything() =
        runTest {
            coEvery { folderApi.addFolder("Friends", "Blogs") } returns NewsBlurResponse()
            val model = model()
            model.chooseFolder("Blogs")
            model.toggleNewFolder()
            model.folderNameChanged("Friends")
            model.submit()
            advanceUntilIdle()
            assertEquals("Blogs ▸ Friends", model.state.value.parent)
            assertEquals(1, model.state.value.folderRevision)
            coVerify(exactly = 0) { feedApi.addFeed(any(), any()) }
        }

    @Test fun networkFailureLeavesQueryAndDestinationAvailableForRetry() =
        runTest {
            coEvery { feedApi.searchForFeed("kottke") } returns null
            val model = model()
            model.chooseFolder("Blogs ▸ Link Blogs")
            model.queryChanged("kottke")
            advanceUntilIdle()
            assertNotNull(model.state.value.error)
            assertFalse(model.state.value.searching)
            assertEquals("kottke", model.state.value.query)
            assertEquals("Blogs ▸ Link Blogs", model.state.value.parent)
        }
}
