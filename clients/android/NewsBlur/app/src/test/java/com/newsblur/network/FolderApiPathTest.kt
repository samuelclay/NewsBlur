package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.Folder
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.NewsBlurResponse
import com.newsblur.util.AppConstants
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okhttp3.FormBody
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class FolderApiPathTest {
    private val network = mockk<NetworkClient>()
    private val api = FolderApiImpl(Gson(), network)
    private val requests = mutableListOf<Map<String, String>>()

    @Before fun setup() {
        FolderPath.supported = false
        FolderPath.setFolders(listOf(folder("Links", "Blogs"), folder("Links", "Art"), folder("People", "Blogs", "Links")))
        val response = mockk<APIResponse>()
        every { response.getResponse(any(), NewsBlurResponse::class.java) } returns NewsBlurResponse()
        coEvery { network.post(any(), any<ValueMultimap>()) } answers {
            val body = secondArg<ValueMultimap>().asFormEncodedRequestBody() as FormBody
            requests += (0 until body.size).associate { body.name(it) to body.value(it) }
            response
        }
    }

    @After fun cleanup() {
        FolderPath.supported = false
        FolderPath.setFolders(emptyList())
    }

    @Test fun addFolderSendsExactParentPathOnSupportingServers() =
        runTest {
            FolderPath.supported = true
            api.addFolder("Friends", "Blogs ▸ Links ▸ People")
            assertEquals("People", requests.single()["parent_folder"])
            assertEquals("[\"Blogs\",\"Links\",\"People\"]", requests.single()["parent_folder_path"])
            assertEquals("Friends", requests.single()["folder"])
        }

    @Test fun olderServersReceiveUniqueLeafNamesAndAnExplicitRoot() =
        runTest {
            api.addFolder("Friends", "Blogs ▸ Links ▸ People")
            api.addFolder("Work", AppConstants.ROOT_FOLDER)
            assertEquals("People", requests[0]["parent_folder"])
            assertEquals("", requests[1]["parent_folder"])
            assertFalse(requests[0].containsKey("parent_folder_path"))
        }

    @Test fun olderServersCannotSilentlyPickTheWrongSameNamedFolder() =
        runTest {
            val result = api.addFolder("Friends", "Blogs ▸ Links")
            assertEquals(FolderPath.AMBIGUOUS_FOLDER, result.message)
            coVerify(exactly = 0) { network.post(any(), any<ValueMultimap>()) }
        }

    @Test fun movesCarryBothCompletePathsIncludingTopLevel() =
        runTest {
            FolderPath.supported = true
            api.moveFeedToFolders("3", linkedSetOf("Art ▸ Links", AppConstants.ROOT_FOLDER), setOf("Blogs ▸ Links"))
            assertEquals("[[\"Art\",\"Links\"],[]]", requests.single()["to_folder_paths"])
            assertEquals("[[\"Blogs\",\"Links\"]]", requests.single()["in_folder_paths"])
        }

    @Test fun renameAndDeleteKeepFullIdentityButSendLeafTitles() =
        runTest {
            FolderPath.supported = true
            api.renameFolder("Blogs ▸ Links", "References", "Blogs")
            api.deleteFolder("Art ▸ Links", "Art")
            assertEquals("Links", requests[0]["folder_to_rename"])
            assertEquals("[\"Blogs\",\"Links\"]", requests[0]["folder_path"])
            assertEquals("[\"Art\",\"Links\"]", requests[1]["folder_path"])
        }

    @Test fun newlyCreatedDuplicateCannotFallBackToAnotherBranchBeforeRefresh() {
        assertTrue(FolderPath.unavailable("Work ▸ People"))
        assertFalse(FolderPath.unavailable("Blogs ▸ Links ▸ People"))
        FolderPath.supported = true
        assertFalse(FolderPath.unavailable("Work ▸ People"))
    }

    @Test fun savedSearchesUseTheServerFolderPathSeparator() {
        assertEquals("Blogs - Links - People", FolderPath.serverName("Blogs ▸ Links ▸ People"))
        assertEquals("", FolderPath.serverName(AppConstants.ROOT_FOLDER))
    }

    private fun folder(
        name: String,
        vararg parents: String,
    ) = Folder().apply {
        this.name = name
        this.parents = listOf(AppConstants.ROOT_FOLDER) + parents
    }
}
