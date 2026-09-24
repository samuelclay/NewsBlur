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

class ClusterReadStoreReconcileTest {
    @Test fun unreadRefreshIncludesEmbeddedReadChildrenWithoutPersistingAllServerUnreadHashes() {
        val db = mockk<SQLiteDatabase>()
        val store = spyk(ClusterReadStore(db))
        val knownRead = "2:read-child"
        val knownUnread = "3:unread-child"
        val serverHashes = listOf(knownRead, knownUnread) + (1..1000).map { "4:uncached-$it" }
        every { db.rawQuery(any(), any()) } answers {
            val values = if (firstArg<String>().startsWith("SELECT DISTINCT child_hash") && firstArg<String>().contains("child_read = 1")) {
                listOf(knownRead)
            } else emptyList()
            var position = -1
            mockk<Cursor>(relaxed = true).also { cursor ->
                every { cursor.moveToNext() } answers { ++position < values.size }
                every { cursor.getString(0) } answers { values[position] }
            }
        }
        every { store.parentsReferencing(any()) } returns mapOf("1:parent" to arrayOf(
            Story.ClusterStory().apply { storyHash = knownRead; read = true },
            Story.ClusterStory().apply { storyHash = knownUnread; read = false },
        ))
        every { store.reconcileServerReadState(any(), any(), any()) } just runs

        store.reconcileServerUnread(serverHashes, 100L)

        verify(exactly = 1) { store.reconcileServerReadState(setOf(knownRead), false, 100L) }
        verify(exactly = 0) { store.parentsReferencing(any()) }
    }
}
