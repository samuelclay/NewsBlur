package com.newsblur.onboarding

import com.newsblur.preference.PrefsRepo
import com.newsblur.database.BlurDatabaseHelper
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

// OnboardingGate.kt checks complete server subscriptions once per login session; unread filters never trigger setup.
@Singleton
class OnboardingGate
    @Inject
    constructor(
        private val api: OnboardingApi,
        private val prefs: PrefsRepo,
        private val db: BlurDatabaseHelper,
    ) {
        private val presented = mutableSetOf<SetupAccount>()

        fun presented() {
            presented.add(api.account())
        }

        suspend fun shouldOpen(): Boolean {
            val account = api.account()
            if (prefs.hasCompletedOnboarding() || !presented.add(account)) return false
            if (withContext(Dispatchers.IO) { db.allFeeds.isNotEmpty() }) return false
            return try {
                hasEmptySubscriptions(api.request("/reader/feeds", mapOf("include_favicons" to "false"), account = account)!!.json)
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                false
            }
        }
    }

// OnboardingGate.kt accepts load_feeds' legacy empty array as well as its populated object shape.
internal fun hasEmptySubscriptions(json: com.google.gson.JsonObject): Boolean {
    if (json.get("authenticated")?.takeIf { it.isJsonPrimitive }?.asString != "true") return false
    val feeds = json.get("feeds") ?: return false
    return (feeds.isJsonObject && feeds.asJsonObject.size() == 0) || (feeds.isJsonArray && feeds.asJsonArray.size() == 0)
}
