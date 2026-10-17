package com.newsblur.marketing

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import com.newsblur.util.FileCache
import com.newsblur.util.LanguageSettings
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.IntoSet
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Protocol
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

/** CookingFixture.kt never proceeds to the network, including for unrecognized endpoints. */
@Singleton
class CookingFixture
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
    ) : Interceptor {
        private val data =
            JSONObject(
                context.assets
                    .open("cooking.json")
                    .bufferedReader()
                    .use { it.readText() },
            )
        private val feeds = data.getJSONArray("feeds").objects()
        private val recipes = data.getJSONArray("stories").objects()
        private val epoch = System.currentTimeMillis() / 1000

        fun prepareImages(
            storyCache: FileCache,
            iconCache: FileCache,
        ) {
            // CookingFixture.kt keeps photographs out of JSON/SQLite; ReadingItemFragment swaps these real cache URLs into its WebView.
            recipes.map { it.getString("photo") }.distinct().forEach { photo ->
                val target = requireNotNull(storyCache.getCachedFile("$SERVER/cooking-photo/$photo.jpg"))
            context.assets.open("photos/$photo.jpg").use { input -> target.outputStream().use { output -> input.copyTo(output) } }
            }
            feeds.forEach { feed ->
                val id = feed.getString("id")
                requireNotNull(iconCache.getCachedFile("$SERVER/cooking-icon/$id.png")).writeBytes(icon(id))
            }
        }

        fun feedsResponse(): JSONObject {
            val mapping = JSONObject()
            feeds.forEach { feed ->
                val id = feed.getString("id")
                mapping.put(
                    id,
                    JSONObject().apply {
                        put("id", id)
                        put("feed_title", feed.getString("title"))
                        put("active", true)
                        put("feed_address", "$SERVER/$id.xml")
                        put("feed_link", "$SERVER/$id")
                        put("favicon_url", "$SERVER/cooking-icon/$id.png")
                        put("favicon_color", feed.getString("color"))
                        put("favicon_fade", feed.getString("color"))
                        put("favicon_border", feed.getString("color"))
                        put("favicon_text_color", "white")
                        put("nt", recipes.count { it.getString("feed_id") == id })
                        put("ps", 0)
                        put("ng", 0)
                    },
                )
            }
            return JSONObject().apply {
                put("authenticated", true)
                put("feeds", mapping)
                put("folders", JSONArray().put(JSONObject().put("Cooking", JSONArray(feeds.map { it.getString("id") }))))
                put("social_feeds", JSONArray())
                put("saved_searches", JSONArray())
                put("starred_counts", JSONArray())
                put("starred_count", recipes.count { it.optBoolean("saved") })
                put(
                    "user_profile",
                    JSONObject().apply {
                        put("is_premium", true)
                        put("is_archive", true)
                        put("is_pro", false)
                        put("premium_expire", 0)
                        put("preferences", JSONObject().put("language", LanguageSettings.selected(context)).put("story_clustering", false))
                    },
                )
            }
        }

        fun storiesResponse(
            saved: Boolean = false,
            feedId: String? = null,
            page: Int = 1,
        ): JSONObject =
            JSONObject().apply {
                val selected =
                    if (page > 1) {
                        emptyList()
                    } else {
                        recipes.filter {
                            (!saved || it.optBoolean("saved")) && (feedId == null || it.getString("feed_id") == feedId)
                        }
                    }
                put("stories", JSONArray(selected.map { story(it, recipes.indexOf(it)) }))
                put("classifiers", JSONObject())
                put("user_profiles", JSONArray())
                put("feed_tags", JSONArray())
                put("feed_authors", JSONArray())
            }

        private fun story(
            recipe: JSONObject,
            index: Int,
        ): JSONObject {
            val photo = recipe.getString("photo")
            val imageUrl = "$SERVER/cooking-photo/$photo.jpg"
            val paragraphs = recipe.getJSONArray("paragraphs")
            val content =
                buildString {
                    append("<p>${paragraphs.getString(0)}</p><p><img src=\"$imageUrl\" style=\"width:100%;height:auto\"></p>")
                    for (i in 1 until paragraphs.length()) append("<p>${paragraphs.getString(i)}</p>")
                }
            return JSONObject().apply {
                put("id", recipe.getString("id"))
                put("story_hash", hash(recipe))
                put("story_feed_id", recipe.getString("feed_id"))
                put("story_title", recipe.getString("title"))
                put("story_authors", recipe.getString("author"))
                put("story_tags", recipe.getJSONArray("tags"))
                put("story_content", content)
                put("story_permalink", "$SERVER/story/${recipe.getString("id")}")
                put("story_timestamp", epoch - (index + 1) * 420)
                put("read_status", 0)
                put("starred", recipe.optBoolean("saved"))
                put("starred_timestamp", epoch - (index + 1) * 420)
                put("image_urls", JSONArray().put(imageUrl))
                put("secure_image_thumbnails", JSONObject().put(imageUrl, imageUrl))
                put(
                    "intelligence",
                    JSONObject()
                        .put("title", 0)
                        .put("author", 0)
                        .put("tags", 0)
                        .put("feed", 0),
                )
            }
        }

        override fun intercept(chain: Interceptor.Chain): Response {
            val request = chain.request()
            val path = request.url.encodedPath.trimEnd('/')
            val bytes: ByteArray
            val type: String
            when {
                path.startsWith("/cooking-photo/") -> {
                    val file = path.substringAfterLast('/')
                    require(file in setOf("pasta.jpg", "salad.jpg", "bread.jpg", "breakfast.jpg", "soup.jpg"))
                    bytes = context.assets.open("photos/$file").use { it.readBytes() }
                    type = "image/jpeg"
                }
                path.startsWith("/cooking-icon/") -> {
                    bytes = icon(path.substringAfterLast('/').substringBefore('.'))
                    type = "image/png"
                }
                else -> {
                    val payload =
                        when {
                            path == "/reader/feeds" -> feedsResponse()
                            path == "/reader/unread_story_hashes" ->
                                JSONObject().put(
                                    "unread_feed_story_hashes",
                                    JSONObject().apply {
                                        feeds.forEach { feed ->
                                            val id = feed.getString("id")
                                            put(
                                                id,
                                                JSONArray(
                                                    recipes.filter { it.getString("feed_id") == id }.map {
                                                        JSONArray().put(hash(it)).put(epoch - (recipes.indexOf(it) + 1) * 420)
                                                    },
                                                ),
                                            )
                                        }
                                    },
                                )
                            path == "/reader/starred_story_hashes" ->
                                JSONObject().put(
                                    "starred_story_hashes",
                                    JSONArray(
                                        recipes
                                            .filter {
                                                it.optBoolean("saved")
                                            }.map(::hash),
                                    ),
                                )
                            path == "/reader/feed_unread_count" -> JSONObject().put("feeds", feedsResponse().getJSONObject("feeds"))
                            path == "/rss_feeds/original_text" ->
                                JSONObject().put(
                                    "original_text",
                                    story(recipes.first(), 0).getString("story_content"),
                                )
                            path.startsWith("/reader/river_stories") ||
                                path.startsWith("/reader/feed/") ||
                                path == "/reader/starred_stories" ->
                                storiesResponse(
                                    path == "/reader/starred_stories",
                                    if (path.startsWith("/reader/feed/")) path.substringAfterLast('/') else null,
                                    request.url.queryParameter("page")?.toIntOrNull() ?: 1,
                                )
                            request.method == "POST" -> JSONObject().put("code", 1)
                            else -> throw IOException("CookingFixture.kt blocked unrecognized capture request: $path")
                        }
                    payload.put("authenticated", true)
                    bytes = payload.toString().toByteArray()
                    type = "application/json"
                }
            }
            return Response
                .Builder()
                .request(request)
                .protocol(Protocol.HTTP_1_1)
                .code(200)
                .message("Capture fixture")
                .body(bytes.toResponseBody(type.toMediaType()))
                .build()
        }

        private fun icon(id: String): ByteArray {
            val feed = feeds.first { it.getString("id") == id }
            val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
            Canvas(bitmap).apply {
                drawColor(Color.parseColor("#${feed.getString("color")}"))
                drawText(
                    feed.getString("title").take(1),
                    27f,
                    68f,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = Color.WHITE
                        textSize = 64f
                        typeface = android.graphics.Typeface.DEFAULT_BOLD
                    },
                )
            }
            return ByteArrayOutputStream().use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                bitmap.recycle()
                it.toByteArray()
            }
        }

        companion object {
            const val SERVER = "https://cooking.newsblur.invalid"
            const val FIRST_STORY_HASH = "910002:cooking-pasta-1"

            private fun hash(recipe: JSONObject) = "${recipe.getString("feed_id")}:${recipe.getString("id")}"

            private fun JSONArray.objects() = (0 until length()).map(::getJSONObject)
        }
    }

@Module
@InstallIn(SingletonComponent::class)
object CaptureNetworkModule {
    @Provides
    @IntoSet
    fun interceptor(fixture: CookingFixture): Interceptor = fixture
}
