package com.newsblur.network

import android.content.Context
import com.google.gson.Gson
import com.google.gson.JsonParseException
import com.google.gson.JsonParser
import com.newsblur.listen.ListenError
import com.newsblur.listen.ListenLibraryResponse
import com.newsblur.listen.ListenManifest
import com.newsblur.listen.ListenPlaybackState
import com.newsblur.listen.ListenPlayedTime
import com.newsblur.listen.ListenProgressResponse
import com.newsblur.listen.ListenQueueItem
import com.newsblur.listen.ListenResult
import com.newsblur.listen.ListenSegmentResponse
import com.newsblur.listen.ListenSpeed
import com.newsblur.listen.ListenUpNextQueue
import com.newsblur.listen.ListenUsage
import com.newsblur.listen.ListenUsageResponse
import com.newsblur.listen.ListenVoicePreviewResponse
import com.newsblur.listen.ListenVoicesResponse
import com.newsblur.util.LanguageSettings
import com.newsblur.util.Log
import com.newsblur.util.NetworkUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import okhttp3.Call
import okhttp3.Callback
import okhttp3.FormBody
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume

/**
 * ListenApiImpl.kt talks to the Listen endpoints directly instead of through NetworkClient.kt, because
 * APIResponse.java drops the body of any non-200 reply and the Listen failures carry a localized
 * message the player shows. It still signs in with NetworkClient.kt's session cookie.
 */
class ListenApiImpl(
    private val context: Context,
    private val gson: Gson,
    private val networkClient: NetworkClient,
    apiClient: OkHttpClient,
    private val userAgent: String,
) : ListenApi {
    // Manifests may wait on original text extraction and language detection, so they get extra time.
    private val client: OkHttpClient =
        apiClient
            .newBuilder()
            .readTimeout(LISTEN_READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .build()

    override suspend fun getVoices(language: String?): ListenResult<ListenVoicesResponse> {
        val params = buildMap { if (!language.isNullOrBlank()) put("language", language) }
        return get(APIConstants.PATH_LISTEN_VOICES, params, ListenVoicesResponse::class.java) {
            ListenEnvelope(it.code, it.reason, it.message, it.usage)
        }
    }

    override suspend fun getLibrary(query: ListenLibraryQuery): ListenResult<ListenLibraryResponse> {
        val params =
            buildMap {
                put("language", query.language)
                query.filters.forEach { (key, value) -> if (value.isNotBlank()) put(key, value) }
                if (query.search.isNotBlank()) put("search", query.search.trim())
                query.sort?.let { put("sort", it) }
                put("page", query.page.toString())
            }
        return get(APIConstants.PATH_LISTEN_LIBRARY, params, ListenLibraryResponse::class.java) {
            ListenEnvelope(it.code, it.reason, it.message, null)
        }
    }

    override suspend fun getManifest(
        storyHash: String,
        language: String?,
        voiceId: String?,
    ): ListenResult<ListenManifest> {
        val form =
            buildMap {
                put(APIConstants.PARAMETER_STORY_HASH, storyHash)
                if (!language.isNullOrBlank()) put("language", language)
                if (!voiceId.isNullOrBlank()) put("voice_id", voiceId)
            }
        return post(APIConstants.PATH_LISTEN_MANIFEST, form, ListenManifest::class.java) {
            ListenEnvelope(it.code, it.reason, it.message, it.usage)
        }
    }

    override suspend fun getSegment(
        manifestId: String,
        index: Int,
    ): ListenResult<ListenSegmentResponse> {
        val form = mapOf("manifest_id" to manifestId, "index" to index.toString())
        return post(APIConstants.PATH_LISTEN_SEGMENT, form, ListenSegmentResponse::class.java) {
            ListenEnvelope(it.code, it.reason, it.message, it.usage)
        }
    }

    override suspend fun getVoicePreview(request: ListenVoicePreviewRequest): ListenResult<ListenVoicePreviewResponse> {
        val form =
            buildMap {
                put("voice_id", request.voiceId)
                request.storyHash
                    ?.takeIf {
                        it.isNotBlank()
                    }?.let { put(APIConstants.PARAMETER_STORY_HASH, it) }
                request.language?.takeIf { it.isNotBlank() }?.let { put("language", it) }
                request.delivery?.let { put("delivery", it) }
                request.stability?.let { put("stability", it.toString()) }
                request.similarity?.let { put("similarity", it.toString()) }
                request.style?.let { put("style", it.toString()) }
                request.speakerBoost?.let { put("speaker_boost", it.toString()) }
            }
        return post(
            APIConstants.PATH_LISTEN_PREVIEW,
            form,
            ListenVoicePreviewResponse::class.java,
        ) {
            ListenEnvelope(it.code, it.reason, it.message, it.usage)
        }
    }

    override suspend fun getUsage(): ListenResult<ListenUsageResponse> =
        get(APIConstants.PATH_LISTEN_USAGE, emptyMap(), ListenUsageResponse::class.java) {
            ListenEnvelope(it.code, it.reason, it.message, it.usage)
        }

    override suspend fun reportProgress(report: ListenProgressReport): Boolean {
        val form =
            buildMap {
                put("manifest_id", report.manifestId)
                put("seconds", ListenPlayedTime.formatSeconds(report.playedMs))
                put("speed", ListenSpeed.prefString(report.speed))
                if (report.finished) put("finished", "true")
            }
        val result =
            post(APIConstants.PATH_LISTEN_PROGRESS, form, ListenProgressResponse::class.java) {
                ListenEnvelope(it.code, it.reason, it.message, null)
            }
        return result is ListenResult.Success
    }

    override suspend fun getPlaybackState(): ListenPlaybackState? {
        val url = APIConstants.buildUrl(APIConstants.PATH_MEDIA_PLAYBACK_STATE).toHttpUrlOrNull() ?: return null
        return mediaPlayerRequest(Request.Builder().url(url).get())
    }

    override suspend fun addToUpNext(item: ListenQueueItem): ListenPlaybackState? =
        mediaPlayerPost(
            APIConstants.PATH_MEDIA_ADD_TO_QUEUE,
            mediaItemForm(item),
        )

    override suspend fun removeFromUpNext(item: ListenQueueItem): ListenPlaybackState? =
        mediaPlayerPost(
            APIConstants.PATH_MEDIA_REMOVE_FROM_QUEUE,
            mapOf("story_hash" to item.storyHash, "media_url" to item.mediaUrl),
        )

    override suspend fun reorderUpNext(queue: List<ListenQueueItem>): ListenPlaybackState? =
        mediaPlayerPost(
            APIConstants.PATH_MEDIA_REORDER_QUEUE,
            mapOf("queue_order" to gson.toJson(ListenUpNextQueue.reorderPayload(queue))),
        )

    override suspend fun addToHistory(
        item: ListenQueueItem,
        positionSeconds: Double,
        durationSeconds: Double,
    ): Boolean {
        val form =
            mediaItemForm(item) +
                mapOf(
                    "position" to secondsField(positionSeconds),
                    "duration" to secondsField(durationSeconds),
                )
        return mediaPlayerPost(APIConstants.PATH_MEDIA_ADD_TO_HISTORY, form) != null
    }

    private fun mediaItemForm(item: ListenQueueItem): Map<String, String> =
        buildMap {
            put("story_hash", item.storyHash)
            put("media_url", item.mediaUrl)
            put("media_type", item.mediaType)
            put("media_title", item.title)
            // apps/media_player/views.py reads feed_id as a number.
            put("feed_id", item.feedId?.toLongOrNull()?.toString() ?: "0")
            put("image_url", item.imageUrl.orEmpty())
        }

    private fun secondsField(seconds: Double): String = String.format(Locale.ROOT, "%.1f", seconds.coerceAtLeast(0.0))

    private suspend fun mediaPlayerPost(
        path: String,
        form: Map<String, String>,
    ): ListenPlaybackState? {
        val body =
            FormBody
                .Builder()
                .apply { form.forEach { (key, value) -> add(key, value) } }
                .build()
        return mediaPlayerRequest(Request.Builder().url(APIConstants.buildUrl(path)).post(body))
    }

    /** /media_player answers {"playback_state": ...} without Listen's code field, so it's read on its own. */
    private suspend fun mediaPlayerRequest(builder: Request.Builder): ListenPlaybackState? {
        if (!NetworkUtils.isOnline(context)) return null
        networkClient.addCookieHeader(builder)
        builder.header("User-Agent", userAgent)
        LanguageSettings.addLanguageHeader(builder, context)
        val request = builder.build()
        val body = withContext(Dispatchers.IO) { fetchBody(request) } ?: return null
        val json =
            try {
                JsonParser.parseString(body).takeIf { it.isJsonObject }?.asJsonObject
            } catch (error: JsonParseException) {
                Log.w(this.javaClass.name, "Media player response from ${request.url.encodedPath} was not JSON: ${error.message}")
                null
            }
        return ListenUpNextQueue.parseResponse(json)
    }

    override fun resolveAudioUrl(url: String): String = resolveListenAudioUrl(url, APIConstants.buildUrl(""))

    override val audioUserAgent: String
        get() = userAgent

    private suspend fun <T> get(
        path: String,
        params: Map<String, String>,
        type: Class<T>,
        envelope: (T) -> ListenEnvelope,
    ): ListenResult<T> {
        val url = APIConstants.buildUrl(path).toHttpUrlOrNull() ?: return networkFailure()
        val withParams =
            url
                .newBuilder()
                .apply { params.forEach { (key, value) -> addQueryParameter(key, value) } }
                .build()
        return execute(Request.Builder().url(withParams).get(), type, envelope)
    }

    private suspend fun <T> post(
        path: String,
        form: Map<String, String>,
        type: Class<T>,
        envelope: (T) -> ListenEnvelope,
    ): ListenResult<T> {
        val body =
            FormBody
                .Builder()
                .apply { form.forEach { (key, value) -> add(key, value) } }
                .build()
        return execute(
            Request.Builder().url(APIConstants.buildUrl(path)).post(body),
            type,
            envelope,
        )
    }

    private suspend fun <T> execute(
        builder: Request.Builder,
        type: Class<T>,
        envelope: (T) -> ListenEnvelope,
    ): ListenResult<T> {
        if (!NetworkUtils.isOnline(context)) return networkFailure()
        networkClient.addCookieHeader(builder)
        builder.header("User-Agent", userAgent)
        LanguageSettings.addLanguageHeader(builder, context)
        val request = builder.build()
        val body = withContext(Dispatchers.IO) { fetchBody(request) } ?: return networkFailure()
        val parsed =
            try {
                gson.fromJson(body, type)
            } catch (error: JsonParseException) {
                Log.w(
                    this.javaClass.name,
                    "Listen response from ${request.url.encodedPath} was not JSON: ${error.message}",
                )
                null
            } catch (error: NumberFormatException) {
                Log.w(
                    this.javaClass.name,
                    "Listen response from ${request.url.encodedPath} had a bad number: ${error.message}",
                )
                null
            } ?: return networkFailure()
        val result = envelope(parsed)
        return if (result.code == 1) {
            ListenResult.Success(parsed)
        } else {
            ListenResult.Failure(ListenError(result.reason, result.message, result.usage))
        }
    }

    /** Returns the response body whatever the status code, or null when nothing arrived. */
    private suspend fun fetchBody(request: Request): String? =
        suspendCancellableCoroutine { continuation ->
            val call = client.newCall(request)
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(
                object : Callback {
                    override fun onFailure(
                        call: Call,
                        e: IOException,
                    ) {
                        Log.w(
                            this@ListenApiImpl.javaClass.name,
                            "Listen request ${request.url.encodedPath} failed: ${e.message}",
                        )
                        if (continuation.isActive) continuation.resume(null)
                    }

                    override fun onResponse(
                        call: Call,
                        response: Response,
                    ) {
                        val body =
                            response.use {
                                try {
                                    it.body.string()
                                } catch (_: IOException) {
                                    null
                                }
                            }
                        if (continuation.isActive) {
                            continuation.resume(
                                body?.takeIf {
                                    it.isNotBlank()
                                },
                            )
                        }
                    }
                },
            )
        }

    private fun networkFailure(): ListenResult.Failure = ListenResult.Failure(ListenError(ListenError.REASON_NETWORK, null))

    private data class ListenEnvelope(
        val code: Int,
        val reason: String?,
        val message: String?,
        val usage: ListenUsage?,
    )

    companion object {
        private const val LISTEN_READ_TIMEOUT_SECONDS = 60L
    }
}

/** ListenApiImpl.kt resolves relative stream paths against the signed-in server, keeping absolute S3 URLs. */
internal fun resolveListenAudioUrl(
    url: String,
    serverBase: String,
): String {
    val trimmed = url.trim()
    if (trimmed.startsWith("http://", ignoreCase = true) ||
        trimmed.startsWith("https://", ignoreCase = true)
    ) {
        return trimmed
    }
    if (trimmed.startsWith("//")) return "https:$trimmed"
    val base = serverBase.trimEnd('/')
    return if (trimmed.startsWith("/")) base + trimmed else "$base/$trimmed"
}
