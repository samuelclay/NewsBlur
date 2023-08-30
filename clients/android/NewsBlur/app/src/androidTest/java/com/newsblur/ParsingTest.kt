package com.newsblur

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
import org.junit.Test
import org.junit.runner.RunWith
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
}