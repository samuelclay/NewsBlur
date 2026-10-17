package com.newsblur.marketing

import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import com.google.gson.Gson
import com.newsblur.BuildConfig
import com.newsblur.NbApplication
import com.newsblur.activity.AllStoriesItemsList
import com.newsblur.activity.AllStoriesReading
import com.newsblur.activity.ItemsList
import com.newsblur.activity.Main
import com.newsblur.activity.Reading
import com.newsblur.activity.SavedStoriesItemsList
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.StarredCount
import com.newsblur.network.APIConstants
import com.newsblur.network.domain.FeedFolderResponse
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FeedSet
import com.newsblur.util.LanguageSettings
import com.newsblur.util.PrefConstants
import com.newsblur.util.ReadFilter
import com.newsblur.util.StateFilter
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

/** StoreCaptureActivity.kt exists only in the separate, debug-signed capture application. */
@AndroidEntryPoint
class StoreCaptureActivity : ComponentActivity() {
    @Inject lateinit var prefsRepo: PrefsRepo
    @Inject lateinit var prefs: SharedPreferences
    @Inject lateinit var db: BlurDatabaseHelper
    @Inject lateinit var fixture: CookingFixture
    @Inject lateinit var gson: Gson

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        check(BuildConfig.DEBUG && packageName == "com.newsblur.storecapture")
        val language = intent.getStringExtra("language") ?: "en"
        val screen = intent.getStringExtra("screen") ?: "stories"
        require(language in LanguageSettings.names)
        require(screen in setOf("feeds", "stories", "reader", "saved"))
        LanguageSettings.select(this, language)
        lifecycleScope.launch {
            withContext(Dispatchers.IO) { seed() }
            val fs = if (screen == "saved") FeedSet.allSaved() else FeedSet.allFeeds()
            val destination = when (screen) {
                "feeds" -> Main::class.java
                "reader" -> AllStoriesReading::class.java
                "saved" -> SavedStoriesItemsList::class.java
                else -> AllStoriesItemsList::class.java
            }
            startActivity(Intent(this@StoreCaptureActivity, destination).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                putExtra(ItemsList.EXTRA_FEED_SET, fs)
                putExtra(Reading.EXTRA_STORY_HASH, CookingFixture.FIRST_STORY_HASH)
            })
            finish()
        }
    }

    private fun seed() {
        prefsRepo.saveCustomServer(CookingFixture.SERVER)
        APIConstants.setCustomServer(CookingFixture.SERVER)
        prefsRepo.saveLogin("cooking-demo", "sessionid=offline-cooking-fixture")
        prefs.edit()
            .putString(PrefConstants.USER_USERNAME, "cooking-demo")
            .putString(PrefConstants.USER_ID, "1")
            .putString(PrefConstants.THEME, "LIGHT")
            .putString(PrefConstants.THEME_LIGHT_VARIANT, "LIGHT")
            .putString(PrefConstants.STATE_FILTER, StateFilter.ALL.name)
            .putString(PrefConstants.STORIES_THUMBNAIL_STYLE, "RIGHT_LARGE")
            .putBoolean(PrefConstants.STORIES_AUTO_OPEN_FIRST, false)
            .putBoolean(PrefConstants.LANGUAGE_DIALOG_SEEN, true)
            .commit()
        prefsRepo.completeOnboarding()
        prefsRepo.updateVersion(NbApplication.getVersion(this))
        prefsRepo.setPremium(true, 0)
        prefsRepo.setArchive(true, 0)
        val feedResponse = FeedFolderResponse(fixture.feedsResponse().toString(), gson)
        val saved = StarredCount().apply { count = feedResponse.starredCount; tag = StarredCount.TOTAL_STARRED }
        db.setFeedsFolders(
            feedResponse.folders.map { it.values }, feedResponse.feeds.map { it.values },
            emptyList(), listOf(saved.values), emptyList(),
        )
        val stories = gson.fromJson(fixture.storiesResponse().toString(), StoriesResponse::class.java)
        db.insertStories(stories, StateFilter.ALL, false)
        db.prepareReadingSession(FeedSet.allFeeds(), StateFilter.ALL, ReadFilter.ALL)
    }
}
