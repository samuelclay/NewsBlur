package com.newsblur

import android.database.AbstractWindowedCursor
import android.database.Cursor
import android.database.CursorWindow
import android.database.sqlite.SQLiteBlobTooBigException
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteDatabase.OpenParams
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.reflect.TypeToken
import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.serialization.BooleanTypeAdapter
import com.newsblur.serialization.ClassifierMapTypeAdapter
import com.newsblur.serialization.DateStringTypeAdapter
import com.newsblur.serialization.StoriesResponseTypeAdapter
import com.newsblur.serialization.StoryTypeAdapter
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import java.lang.reflect.Field
import java.util.Arrays
import java.util.Date

@RunWith(AndroidJUnit4::class)
class ParsingTest {

    @Test
    fun test() {
        val gson: Gson = GsonBuilder().apply {
            registerTypeAdapter(Date::class.java, DateStringTypeAdapter())
            registerTypeAdapter(Boolean::class.java, BooleanTypeAdapter())
            registerTypeAdapter(Boolean::class.javaPrimitiveType, BooleanTypeAdapter())
            registerTypeAdapter(Story::class.java, StoryTypeAdapter())
            registerTypeAdapter(StoriesResponse::class.java, StoriesResponseTypeAdapter())
            registerTypeAdapter(object : TypeToken<Map<String?, Classifier?>?>() {}.type, ClassifierMapTypeAdapter())
        }.create()

        val input = """""".trimIndent()
    }

    /**
     * https://android.googlesource.com/platform/cts/+/master/tests/tests/database/src/android/database/sqlite/cts/SQLiteCursorTest.java
     * New cursor window constructor from API 28+
     */
    @Test
    fun testRowTooBig() {
        val mDatabase = SQLiteDatabase.createInMemory(OpenParams.Builder().build())
        mDatabase.execSQL("CREATE TABLE Tst (Txt BLOB NOT NULL);")
        val testArr = ByteArray(10000)
        Arrays.fill(testArr, 1.toByte())
        for (i in 0..9) {
            mDatabase.execSQL("INSERT INTO Tst VALUES (?)", arrayOf<Any>(testArr))
        }
        // Now reduce window size, so that no rows can fit
        val cursor: Cursor = mDatabase.rawQuery("SELECT * FROM TST", null)
        val cw = CursorWindow("test", 5000)
        val ac = cursor as AbstractWindowedCursor
        ac.window = cw
        try {
            ac.moveToNext()
            fail("Exception is expected when row exceeds CursorWindow size")
        } catch (expected: SQLiteBlobTooBigException) {
        }
    }

    @Test
    fun cursorWindowReflection() {
        try {
            val field: Field = CursorWindow::class.java.getDeclaredField("sCursorWindowSize")
            field.isAccessible = true
            field.set(null, 100 * 1024 * 1024) //the 100MB is the new size
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}