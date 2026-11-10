package com.newsblur.database

import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.Assert.assertNull
import org.junit.Test

class Test_NullFeedLookup {
    @Test
    fun test_missing_feed_id_does_not_bind_null_to_sqlite() {
        val database = mockk<SQLiteDatabase>()
        val helper = mockk<BlurDatabaseHelper>()
        BlurDatabaseHelper::class.java.getDeclaredField("dbRO").apply {
            isAccessible = true
            set(helper, database)
        }
        every { helper.getFeed(any()) } answers { callOriginal() }
        every { database.query(any(), any(), any(), any(), any(), any(), any(), any()) } answers {
            require(arg<Array<String?>>(3).none { it == null }) { "the bind value at index 1 is null" }
            mockk<Cursor>(relaxed = true)
        }

        assertNull(helper.getFeed(null))
        verify(exactly = 0) { database.query(any(), any(), any(), any(), any(), any(), any(), any()) }
    }
}
