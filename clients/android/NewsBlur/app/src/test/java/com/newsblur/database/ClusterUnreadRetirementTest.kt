package com.newsblur.database

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import com.newsblur.domain.Story
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.runs
import io.mockk.spyk
import io.mockk.verify
import org.junit.Test

class ClusterUnreadRetirementTest {
    @Test fun remoteReadRetiresAnEmbeddedOnlyUnreadChild() {
        val hash = "2:embedded"
        val db = mockk<SQLiteDatabase>()
        val store = spyk(ClusterReadStore(db))
        every { db.rawQuery(any(), any()) } answers {
            var position = -1
            mockk<Cursor>(relaxed = true).also { cursor ->
                every { cursor.moveToNext() } answers { ++position == 0 }
                every { cursor.getString(0) } returns hash
            }
        }
        every { store.parentsReferencing(any()) } returns mapOf(
            "1:parent" to arrayOf(Story.ClusterStory().apply { storyHash = hash; feedId = "2"; read = false }),
        )
        every { store.reconcileServerReadState(any(), any(), any()) } just runs

        // UnreadsSubService.kt receives no unread hashes after another device marks this child read.
        store.reconcileServerUnread(emptyList(), 200L)

        verify(exactly = 1) { store.reconcileServerReadState(setOf(hash), true, 200L) }
    }
}
