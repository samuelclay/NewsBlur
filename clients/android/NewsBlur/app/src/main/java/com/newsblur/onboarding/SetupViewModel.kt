package com.newsblur.onboarding

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.JsonParser
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.discover.DiscoveryFeed
import com.newsblur.discover.obj
import com.newsblur.discover.objects
import com.newsblur.discover.string
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import javax.inject.Inject
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

data class SetupState(
    val loading: Boolean = true,
    val categories: List<String> = emptyList(),
    val icons: Map<String, Bitmap> = emptyMap(),
    val cardIcons: Map<String, List<String>> = emptyMap(),
    val iconFailures: Set<String> = emptySet(),
    val category: String? = null,
    val bundleLoading: Boolean = false,
    val choices: BundleChoices = BundleChoices(),
    val folder: String = "",
    val query: String = "",
    val search: List<DiscoveryFeed> = emptyList(),
    val searching: Boolean = false,
    val unavailable: Set<String> = emptySet(),
    val existingFolders: List<String> = listOf(""),
    val error: String? = null,
    val bundleError: String? = null,
    val importing: Boolean = false,
    val importMessage: String? = null,
)

@HiltViewModel
class SetupViewModel
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
        private val api: OnboardingApi,
        val queue: SetupQueue,
        private val db: BlurDatabaseHelper,
    ) : ViewModel() {
        private val mutable = MutableStateFlow(SetupState())
        val state = mutable.asStateFlow()
        private val account = api.account()
        private val audited = OnboardingCatalog.read(context)
        private val excluded =
            context.assets
                .open(
                    "onboarding_exclusions.json",
                ).bufferedReader()
                .use { JsonParser.parseReader(it).asJsonObject }
        private val semaphore = Semaphore(8)
        private val iconTasks = mutableMapOf<String, Deferred<Bitmap?>>()
        private val categoryTasks = mutableMapOf<String, Job>()
        private val candidates = mutableMapOf<String, List<DiscoveryFeed>>()
        private val candidateTasks = mutableMapOf<String, Job>()
        private var searchJob: Job? = null
        private val language = LanguageIdentification.getClient()

        init {
            queue.bind(account)
            loadCatalog()
            viewModelScope.launch {
                queue.state.collect { progress ->
                    mutable.update {
                        it.copy(
                            importing = progress.importing,
                            importMessage = progress.importMessage ?: progress.importError,
                            choices = it.choices.copy(selected = it.choices.selected - progress.added - progress.queued),
                        )
                    }
                }
            }
            refreshSubscriptions()
            viewModelScope.launch {
                com.newsblur.service.NbSyncManager.state.collect { event ->
                    if (event is com.newsblur.service.NBSync.Update &&
                        event.type and com.newsblur.service.NbSyncManager.UPDATE_METADATA != 0
                    ) {
                        refreshSubscriptions()
                    }
                }
            }
        }

        private fun refreshSubscriptions() =
            viewModelScope.launch {
                val (feeds, folders) =
                    withContext(Dispatchers.IO) {
                        db.allFeeds.mapNotNull(db::getFeed) to
                            db.folders
                                .sortedWith(com.newsblur.domain.Folder.FolderComparator)
                                .map { it.flatName() }
                                .filter { it != com.newsblur.util.AppConstants.ROOT_FOLDER }
                    }
                if (!api.isCurrent(account)) return@launch
                val unavailable = feeds.map { it.address }.toSet()
                mutable.update {
                    it.copy(
                        unavailable = unavailable,
                        existingFolders = listOf("") + folders,
                        choices = it.choices.copy(selected = it.choices.selected - unavailable),
                    )
                }
            }

        fun loadCatalog() =
            viewModelScope.launch {
                mutable.update { it.copy(loading = true, error = null) }
                try {
                    val json = api.request("/discover/popular_feeds", mapOf("type" to "all", "limit" to "1"), account = account)!!.json
                    val categories = OnboardingCatalog.categories(json.getAsJsonArray("categories")?.map { it.asString }.orEmpty())
                    check(categories.isNotEmpty()) { "No interests are available yet. Please try again." }
                    mutable.update { it.copy(categories = categories) }
                } catch (
                    cancel: CancellationException,
                ) {
                    throw cancel
                } catch (
                    e: Exception,
                ) {
                    mutable.update { it.copy(error = e.message) }
                } finally {
                    mutable.update { it.copy(loading = false) }
                }
            }

        private suspend fun icon(id: String): Bitmap? {
            if (id.isBlank()) return null
            val task =
                iconTasks.getOrPut(id) {
                    viewModelScope.async {
                        semaphore.withPermit {
                            try {
                                val json = api.request("/reader/favicons", mapOf("feed_ids" to id), account = account)!!.json
                                val bitmap = withContext(Dispatchers.Default) { OnboardingCatalog.bitmap(json.string(id)) }
                                bitmap?.takeIf { OnboardingCatalog.fingerprint(it) != null }?.also { image ->
                                    mutable.update {
                                        it.copy(
                                            icons =
                                                it.icons + (id to image),
                                        )
                                    }
                                }
                            } catch (cancel: CancellationException) {
                                throw cancel
                            } catch (_: Exception) {
                                null
                            }
                        }
                    }
                }
            return task.await()
        }

        fun loadIcons(category: String) {
            if (categoryTasks[category]?.isActive == true ||
                mutable.value.cardIcons[category]
                    .orEmpty()
                    .size >= 5
            ) {
                return
            }
            categoryTasks[category] =
                viewModelScope.launch {
                    val ids =
                        mutable.value.cardIcons[category]
                            .orEmpty()
                            .toMutableList()
                    val hashes = ids.mapNotNull { mutable.value.icons[it]?.let(OnboardingCatalog::fingerprint) }.toMutableSet()

                    suspend fun append(feed: DiscoveryFeed) {
                        val image = icon(feed.id) ?: return
                        val hash = OnboardingCatalog.fingerprint(image) ?: return
                        if (ids.size < 5 && feed.id !in ids && hashes.add(hash)) {
                            ids.add(feed.id)
                            mutable.update { it.copy(cardIcons = it.cardIcons + (category to ids.toList())) }
                        }
                    }
                    coroutineScope {
                        audited[category]
                            .orEmpty()
                            .take(5)
                            .map { feed -> launch { append(feed) } }
                            .joinAll()
                    }
                    audited[category]
                        .orEmpty()
                        .drop(5)
                        .take(5)
                        .forEach { if (ids.size < 5) append(it) }
                    mutable.update { it.copy(iconFailures = if (ids.size < 5) it.iconFailures + category else it.iconFailures - category) }
                }
        }

        fun retryIcons() {
            iconTasks.entries.removeAll { it.value.isCompleted && it.key !in mutable.value.icons }
            mutable.value.iconFailures.forEach(::loadIcons)
        }

        private suspend fun english(text: String): List<Pair<String, Float>> =
            suspendCancellableCoroutine { continuation ->
                language
                    .identifyPossibleLanguages(text)
                    .addOnSuccessListener {
                        if (continuation.isActive) {
                            continuation.resume(
                                it.map { result ->
                                    result.languageTag to
                                        result.confidence
                                },
                            )
                        }
                    }.addOnFailureListener { if (continuation.isActive) continuation.resumeWithException(it) }
            }

        private suspend fun validate(
            entries: List<com.google.gson.JsonObject>,
            category: String,
        ): List<DiscoveryFeed> {
            val result = mutableListOf<DiscoveryFeed>()
            val blocked = excluded.getAsJsonArray(category)?.map { it.asString }.orEmpty()
            for (entry in entries) {
                val feed = DiscoveryFeed.parse(entry) ?: continue
                val raw = entry.obj("feed") ?: entry
                if (feed.url in blocked ||
                    raw.string("has_feed_exception") == "true" ||
                    (raw.string("has_exception") == "true" && raw.string("exception_type") == "feed")
                ) {
                    continue
                }
                val latest =
                    (
                        feed.stories.mapNotNull { it.timestamp } +
                            listOfNotNull(
                                com.newsblur.util.DiscoverFeedFreshnessFormatter
                                    .parseApiDateMillis(feed.lastStoryDate)
                                    ?.div(1000),
                            )
                    ).maxOrNull()
                        ?: continue
                val age = System.currentTimeMillis() / 1000 - latest
                if (age !in -86400..365L * 86400) continue
                val titles = feed.stories.map { it.title.replace(Regex("<[^>]+>"), " ") }.filter { it.count(Char::isLetter) >= 8 }
                if (titles.size < 3) continue
                val dominant = english(titles.joinToString(". ")).maxByOrNull { it.second }
                if (dominant == null || dominant.first != "en" || dominant.second < .6f) continue
                var multilingual = false
                for (title in titles.filter { it.split(" ").size >= 4 }) {
                    val detected = english(title).maxByOrNull { it.second }
                    if (detected != null &&
                        detected.first != "en" &&
                        detected.first != "und" &&
                        detected.second >= .7f
                    ) {
                        multilingual = true
                        break
                    }
                }
                if (multilingual) continue
                val bitmap =
                    OnboardingCatalog.bitmap(raw.string("favicon"))?.takeIf { OnboardingCatalog.fingerprint(it) != null } ?: icon(feed.id)
                        ?: try {
                            semaphore.withPermit { api.thumbnail(feed.image)?.takeIf { OnboardingCatalog.fingerprint(it) != null } }
                        } catch (
                            _: Exception,
                        ) {
                            null
                        }
                        ?: continue
                mutable.update { it.copy(icons = it.icons + (feed.id.ifBlank { feed.url } to bitmap)) }
                result.add(feed)
            }
            return result.distinctBy { it.url }.sortedByDescending { it.subscribers }
        }

        fun openBundle(category: String) {
            mutable.update {
                it.copy(
                    category = category,
                    folder = if (category.isEmpty()) "My Favorites" else OnboardingCatalog.title(category),
                    choices = BundleChoices(),
                    bundleLoading = true,
                    bundleError = null,
                )
            }
            append(category, candidates[category].orEmpty())
            if (candidateTasks[category]?.isActive == true) return
            if (candidates[category].orEmpty().size >= 15) {
                mutable.update { it.copy(bundleLoading = false) }
                return
            }
            candidateTasks[category] =
                viewModelScope.launch {
                    val pools = mutableMapOf<String, List<DiscoveryFeed>>()
                    var error: String? = null
                    coroutineScope {
                        OnboardingCatalog.sources
                            .map { source ->
                                launch {
                                    try {
                                        val params =
                                            mapOf(
                                                "type" to source,
                                                "limit" to "20",
                                                "exclude_subscribed" to "false",
                                                "staleness" to "year",
                                                "include_stories" to "true",
                                            ) +
                                                if (category.isEmpty()) emptyMap() else mapOf("category" to category)
                                        val json = api.request("/discover/popular_feeds", params, account = account)!!.json
                                        val feeds = validate(json.objects("feeds"), category)
                                        pools[source] = feeds
                                        append(category, feeds.take(3))
                                    } catch (cancel: CancellationException) {
                                        throw cancel
                                    } catch (e: Exception) {
                                        error = e.message
                                    }
                                }
                            }.joinAll()
                    }
                    for (i in 0 until 20) append(category, OnboardingCatalog.sources.mapNotNull { pools[it]?.getOrNull(i) })

                    fun distinctIcons(): List<DiscoveryFeed> =
                        candidates[category].orEmpty().distinctBy {
                            mutable.value.icons[it.id.ifBlank { it.url }]?.let(OnboardingCatalog::fingerprint)
                        }
                    if (distinctIcons().size < 5) {
                        for (alias in OnboardingCatalog.categoryAliases(category)) {
                            try {
                                val params =
                                    mapOf(
                                        "type" to "all",
                                        "limit" to "80",
                                        "exclude_subscribed" to "false",
                                        "staleness" to "year",
                                        "include_stories" to "true",
                                    ) +
                                        if (alias.isEmpty()) emptyMap() else mapOf("category" to alias)
                                val json = api.request("/discover/popular_feeds", params, account = account)!!.json
                                append(category, validate(json.objects("feeds"), category))
                            } catch (cancel: CancellationException) {
                                throw cancel
                            } catch (e: Exception) {
                                error = e.message
                            }
                        }
                    }
                    val readyIcons = distinctIcons().take(5).map { it.id.ifBlank { it.url } }
                    if (readyIcons.size >= 5) {
                        mutable.update {
                            it.copy(cardIcons = it.cardIcons + (category to readyIcons), iconFailures = it.iconFailures - category)
                        }
                    }
                    mutable.update {
                        if (it.category ==
                            category
                        ) {
                            it.copy(
                                bundleLoading = false,
                                bundleError =
                                    if (readyIcons.size < 5) {
                                        error
                                            ?: "These feeds aren’t ready yet. Please try again."
                                    } else {
                                        null
                                    },
                            )
                        } else {
                            it
                        }
                    }
                }
        }

        private fun append(
            category: String,
            feeds: List<DiscoveryFeed>,
        ) {
            candidates[category] = (candidates[category].orEmpty() + feeds).distinctBy { it.url }.take(15)
            val unavailable = mutable.value.unavailable + queue.state.value.added + queue.state.value.queued
            mutable.update { if (it.category == category) it.copy(choices = it.choices.append(feeds, unavailable)) else it }
        }

        fun closeBundle() {
            mutable.update { it.copy(category = null, bundleLoading = false) }
        }

        fun folder(value: String) {
            mutable.update { it.copy(folder = value) }
        }

        fun toggle(url: String) {
            if (url in mutable.value.unavailable || url in queue.state.value.queued || url in queue.state.value.added) return
            mutable.update { it.copy(choices = it.choices.toggle(url)) }
        }

        fun addBundle() {
            val current = mutable.value
            if (current.folder.isBlank()) return
            queue.enqueue(current.choices.feeds.filter { it.url in current.choices.selected }, current.folder.trim(), current.category)
            closeBundle()
        }

        fun addSearch(
            feed: DiscoveryFeed,
            folder: String,
        ) {
            if (feed.url in mutable.value.unavailable) return
            queue.enqueue(listOf(feed), folder, existing = true)
        }

        fun search(query: String) {
            searchJob?.cancel()
            mutable.update { it.copy(query = query, search = emptyList(), searching = query.isNotBlank(), error = null) }
            if (query.isBlank()) return
            searchJob =
                viewModelScope.launch {
                    delay(300)
                    try {
                        val json =
                            api
                                .request(
                                    "/discover/autocomplete",
                                    mapOf("term" to query, "v" to "2", "format" to "full", "limit" to "20"),
                                    account = account,
                                )!!
                                .json
                        val feeds = json.objects("feeds").mapNotNull { DiscoveryFeed.parse(it, true) }
                        mutable.update { it.copy(search = feeds) }
                        feeds.forEach { feed -> launch { icon(feed.id) } }
                    } catch (
                        cancel: CancellationException,
                    ) {
                        throw cancel
                    } catch (
                        e: Exception,
                    ) {
                        mutable.update { it.copy(error = e.message) }
                    } finally {
                        if (mutable.value.query == query) mutable.update { it.copy(searching = false) }
                    }
                }
        }

        fun import(uri: Uri) {
            mutable.update { it.copy(error = null) }
            queue.import(uri)
        }

        override fun onCleared() {
            language.close()
        }
    }
