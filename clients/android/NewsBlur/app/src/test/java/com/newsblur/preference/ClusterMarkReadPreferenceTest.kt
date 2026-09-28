package com.newsblur.preference

import android.content.SharedPreferences
import com.google.gson.Gson
import com.newsblur.network.domain.FeedFolderResponse
import com.newsblur.util.PrefConstants
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClusterMarkReadPreferenceTest {
    private val preferences = mockk<SharedPreferences> {
        every { getBoolean(any(), any()) } answers { secondArg() }
    }
    private val repo = PrefsRepo(preferences, mockk(relaxed = true))

    private fun enabled(): Boolean = repo.isClusterMarkReadEnabled()

    private fun serverPreference(preferences: String): Boolean {
        val response = FeedFolderResponse(
            """{"authenticated":true,"folders":[],"feeds":[],"user_profile":{"is_premium":true,"premium_expire":0,"is_archive":true,"preferences":$preferences}}""",
            Gson(),
        )
        return response.clusterMarkRead
    }

    @Test fun accountPreferenceHydratesTrueAndExplicitFalse() {
        assertTrue(serverPreference("""{"cluster_mark_read":true}"""))
        assertFalse(serverPreference("""{"cluster_mark_read":false}"""))
        assertTrue(serverPreference(Gson().toJson("""{"cluster_mark_read":true}""")))
    }

    @Test fun absentPreferenceUsesTheWebDefault() {
        assertFalse(serverPreference("{}"))
        assertFalse(serverPreference("null"))
        every { preferences.getBoolean(PrefConstants.IS_ARCHIVE, false) } returns true
        assertFalse(enabled())
    }

    @Test fun enablingRequiresArchiveAndPreservesExplicitOff() {
        every { preferences.getBoolean("cluster_mark_read", false) } returns true
        assertFalse(enabled())
        every { preferences.getBoolean(PrefConstants.IS_ARCHIVE, false) } returns true
        assertTrue(enabled())
        every { preferences.getBoolean("cluster_mark_read", false) } returns false
        assertFalse(enabled())
    }
}
