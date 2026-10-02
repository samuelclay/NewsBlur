package com.newsblur.discover

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.domain.Feed
import com.newsblur.domain.Folder
import com.newsblur.domain.FolderHierarchy
import com.newsblur.network.FeedApi
import com.newsblur.network.FolderPath
import com.newsblur.preference.DiscoveryViewPreferences
import com.newsblur.util.AppConstants
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.withContext
import java.io.IOException
import java.util.UUID
import javax.inject.Inject

data class DiscoveryState(
    val tab: DiscoveryTab = DiscoveryTab.SEARCH,
    val pages: Map<DiscoveryTab, DiscoveryPage> = emptyMap(),
    val grid: Boolean = false,
    val folder: String = AppConstants.ROOT_FOLDER,
    val folders: List<Folder> = emptyList(),
    val added: Set<String> = emptySet(),
    val busy: Boolean = false,
    val error: String? = null,
    val notice: String? = null,
    val revision: Int = 0,
    val preview: Feed? = null,
    val previewStoryHash: String? = null,
    val selectedPreviewStoryHash: String? = null,
    val web: WebDiscoveryState = WebDiscoveryState(),
    val newsQuery: String = "",
    val newsTopic: String = "",
    val newsCategory: String = "",
    val language: String = "en",
) {
    val page: DiscoveryPage get() = pages[tab] ?: DiscoveryPage()
}

@HiltViewModel
class DiscoveryViewModel
    @Inject
    constructor(
        private val api: DiscoveryApi,
        private val feedApi: FeedApi,
        private val saved: SavedStateHandle,
        private val viewPreferences: DiscoveryViewPreferences,
    ) : ViewModel() {
        internal var workerDispatcher: CoroutineDispatcher = Dispatchers.IO
        private val ownerAccount = viewPreferences.folderSelection().account
        private val mutable =
            MutableStateFlow(
                DiscoveryState(
                    tab = DiscoveryTab.entries.firstOrNull { it.name == saved.get<String>(TAB) } ?: DiscoveryTab.SEARCH,
                    grid = viewPreferences.isGrid(),
                    folder = viewPreferences.folderSelection().folder,
                    selectedPreviewStoryHash = saved["selectedPreviewStoryHash"],
                    newsQuery = saved["newsQuery"] ?: "",
                    newsTopic = saved["newsTopic"] ?: "",
                    newsCategory = saved["newsCategory"] ?: "",
                    language = saved["language"] ?: "en",
                    web = WebDiscoveryState(url = saved["webUrl"] ?: "", hint = saved["webHint"] ?: ""),
                    pages = DiscoveryTab.entries.associateWith { tab -> DiscoveryPage(query = saved["query_${tab.name}"] ?: "") },
                ),
            )
        val state = mutable.asStateFlow()
        private val jobs = mutableMapOf<DiscoveryTab, Job>()
        private val generations = mutableMapOf<DiscoveryTab, Int>()
        private var webJob: Job? = null
        private var webGeneration = 0

        init {
            viewModelScope.launch {
                viewPreferences.gridChanges.collect { grid -> mutable.update { it.copy(grid = grid) } }
            }
            viewModelScope.launch {
                viewPreferences.folderChanges.collect { selection ->
                    mutable.update {
                        if (selection.account == ownerAccount) {
                            it.copy(folder = selection.folder)
                        } else {
                            it.copy(folder = AppConstants.ROOT_FOLDER, folders = emptyList(), added = emptySet())
                        }
                    }
                }
            }
        }

        private fun page(
            tab: DiscoveryTab,
            change: (DiscoveryPage) -> DiscoveryPage,
        ) {
            mutable.update { it.copy(pages = it.pages + (tab to change(it.pages[tab] ?: DiscoveryPage()))) }
        }

        fun start() {
            selectTab(state.value.tab)
        }

        fun selectTab(tab: DiscoveryTab) {
            saved[TAB] = tab.name
            mutable.update { it.copy(tab = tab, error = null, notice = null) }
            if (tab != DiscoveryTab.WEB && tab != DiscoveryTab.GOOGLE && !state.value.page.loaded && !state.value.page.loading) load(tab)
        }

        fun setFolders(
            folders: List<Folder>,
            subscribed: Set<String>,
        ) {
            if (viewPreferences.folderSelection().account != ownerAccount) return
            FolderPath.setFolders(folders)
            mutable.update { it.copy(folders = FolderHierarchy(folders).ordered, added = it.added + subscribed) }
            val selected = viewPreferences.folderSelection().folder
            if (selected != AppConstants.ROOT_FOLDER && folders.none { it.flatName() == selected }) {
                chooseFolder(AppConstants.ROOT_FOLDER)
            }
        }

        fun chooseFolder(folder: String) {
            if (viewPreferences.folderSelection().account != ownerAccount) return
            viewPreferences.setFolder(folder)
            mutable.update { it.copy(folder = viewPreferences.folderSelection().folder) }
        }

        // DiscoverSitesActivity.kt calls this only for an explicit fresh launch or compact-sheet context.
        fun seedFolder(folder: String) {
            if (folder.isNotBlank() && folder != AppConstants.ROOT_FOLDER) chooseFolder(folder)
        }

        fun toggleGrid() {
            val grid = !viewPreferences.isGrid()
            viewPreferences.setGrid(grid)
            mutable.update { it.copy(grid = grid) }
        }

        fun queryChanged(query: String) {
            val tab = state.value.tab
            saved["query_${tab.name}"] = query
            page(tab) { it.copy(query = query) }
            load(tab, debounce = true)
        }

        fun filter(
            category: String = state.value.page.category,
            subcategory: String = "",
            platform: String = state.value.page.platform,
        ) {
            val tab = state.value.tab
            page(tab) { it.copy(category = category, subcategory = subcategory, platform = platform) }
            load(tab)
        }

        fun retry() = load(state.value.tab)

        fun more() {
            if (state.value.page.hasMore && !state.value.page.loading) load(state.value.tab, append = true)
        }

        private fun load(
            tab: DiscoveryTab,
            append: Boolean = false,
            debounce: Boolean = false,
        ) {
            jobs[tab]?.cancel()
            val token = (generations[tab] ?: 0) + 1
            generations[tab] = token
            val snapshot = state.value.pages[tab] ?: DiscoveryPage()
            page(tab) { it.copy(loading = true, error = null, feeds = if (append) it.feeds else emptyList(), hasMore = false) }
            jobs[tab] =
                viewModelScope.launch {
                    if (debounce) delay(350)
                    try {
                        val query = snapshot.query.trim()
                        val offset = if (append) snapshot.offset else 0
                        val params = mutableMapOf("type" to tab.type, "limit" to "20", "offset" to "$offset", "include_stories" to "true")
                        if (query.isNotBlank()) params["query"] = query
                        if (snapshot.category.isNotBlank()) params["category"] = snapshot.category
                        if (snapshot.subcategory.isNotBlank()) params["subcategory"] = snapshot.subcategory
                        if (snapshot.platform.isNotBlank()) params["platform"] = snapshot.platform
                        val json =
                            when {
                                tab == DiscoveryTab.SEARCH && query.isBlank() ->
                                    request(
                                        "/discover/trending",
                                        mapOf(
                                            "page" to "1",
                                            "days" to "7",
                                            "limit" to "20",
                                        ),
                                    )
                                tab == DiscoveryTab.SEARCH ->
                                    request(
                                        "/discover/autocomplete",
                                        mapOf(
                                            "term" to query,
                                            "v" to "2",
                                            "format" to "full",
                                            "limit" to "20",
                                        ),
                                    )
                                tab == DiscoveryTab.NEWSLETTERS && isAddress(query) ->
                                    request(
                                        "/discover/newsletter/convert",
                                        mapOf(
                                            "url" to query,
                                        ),
                                    )
                                else -> {
                                    if (query.isNotBlank() &&
                                        tab in listOf(DiscoveryTab.YOUTUBE, DiscoveryTab.REDDIT, DiscoveryTab.PODCASTS)
                                    ) {
                                        loadSourceAndCatalog(tab, token, query, params)
                                        return@launch
                                    }
                                    request("/discover/popular_feeds", params)
                                }
                            }
                        if (generations[tab] != token) return@launch
                        val trending =
                            json.obj("trending_feeds")?.entrySet()?.mapNotNull {
                                it.value
                                    .takeIf { value ->
                                        value.isJsonObject
                                    }?.asJsonObject
                            }
                        val entries = trending ?: if (json.string("feed_url").isNotBlank()) listOf(json) else json.objects("feeds")
                        val feeds = entries.mapNotNull { DiscoveryFeed.parse(it, tab == DiscoveryTab.SEARCH) }
                        page(tab) { current ->
                            current.copy(
                                feeds = ((if (append) current.feeds else emptyList()) + feeds).distinctBy { it.url },
                                loading = false,
                                loaded = true,
                                offset = offset + entries.size,
                                hasMore = tab != DiscoveryTab.SEARCH && json.string("has_more") == "true" && entries.isNotEmpty(),
                                categories =
                                    json
                                        .objects("grouped_categories")
                                        .map {
                                            DiscoveryCategory(
                                                it.string("name"),
                                                it.objects("subcategories").map { sub ->
                                                    sub.string("name")
                                                },
                                            )
                                        }.ifEmpty { current.categories },
                                platforms = json.obj("platform_counts")?.keySet()?.sorted() ?: current.platforms,
                            )
                        }
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (error: Exception) {
                        if (generations[tab] ==
                            token
                        ) {
                            page(tab) { it.copy(loading = false, error = error.message ?: "Couldn’t load sites. Please try again.") }
                        }
                    }
                }
        }

        private suspend fun loadSourceAndCatalog(
            tab: DiscoveryTab,
            token: Int,
            query: String,
            params: Map<String, String>,
        ) = supervisorScope {
            val results = arrayOf<List<DiscoveryFeed>>(emptyList(), emptyList())
            val errors = arrayOfNulls<String>(2)
            listOf("/discover/popular_feeds" to params, "/discover/${tab.type}/search" to mapOf("query" to query))
                .mapIndexed {
                    index,
                    (path, values),
                    ->
                    async {
                        try {
                            val json = request(path, values)
                            results[index] =
                                (json.objects("feeds").ifEmpty { json.objects("results") }).mapNotNull { DiscoveryFeed.parse(it) }
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (error: Exception) {
                            errors[index] = error.message
                        }
                        if (generations[tab] ==
                            token
                        ) {
                            page(tab) { it.copy(feeds = results.flatMap { feeds -> feeds }.distinctBy { feed -> feed.url }) }
                        }
                    }
                }.forEach { it.await() }
            if (generations[tab] ==
                token
            ) {
                page(
                    tab,
                ) { it.copy(loading = false, loaded = true, error = if (it.feeds.isEmpty()) errors.filterNotNull().lastOrNull() else null) }
            }
        }

        fun add(feed: DiscoveryFeed) =
            action {
                if (feed.url in state.value.added) return@action
                addUrl(feed.url)
            }

        private suspend fun addUrl(url: String) {
            val folder = selectedFolder()
            val response = withContext(workerDispatcher) { feedApi.addFeed(url, folder) }
            if (response == null ||
                response.isError ||
                response.feed?.feedId.isNullOrBlank()
            ) {
                throw IOException(
                    response?.getErrorMessage("Couldn’t add this site.") ?: "Couldn’t add this site.",
                )
            }
            added(url)
        }

        private fun selectedFolder(): String {
            val selection = viewPreferences.folderSelection()
            if (selection.account != ownerAccount) throw IOException("Your account changed. Reopen discovery to add a site.")
            return selection.folder
        }

        private fun added(url: String) {
            mutable.update { it.copy(added = it.added + url, notice = "Site added", revision = it.revision + 1) }
        }

        fun preview(feed: DiscoveryFeed, story: DiscoveryStory? = null) {
            if (state.value.busy || state.value.preview != null || (story != null && story.hash.isBlank())) return
            val previousSelection = state.value.selectedPreviewStoryHash
            val hash = story?.hash
            selectPreviewStory(hash)
            action {
                try {
                    val id = feed.id.ifBlank { request("/discover/link_popular_feed", mapOf("feed_url" to feed.url)).string("feed_id") }
                    if ((id.toLongOrNull() ?: 0) <= 0) throw IOException("Couldn’t prepare this feed for preview.")
                    mutable.update { it.copy(preview = feed.asFeed(id), previewStoryHash = hash) }
                } catch (error: Exception) {
                    selectPreviewStory(previousSelection)
                    throw error
                }
            }
        }

        private fun selectPreviewStory(hash: String?) {
            saved["selectedPreviewStoryHash"] = hash
            mutable.update { it.copy(selectedPreviewStoryHash = hash) }
        }

        fun previewOpened() {
            mutable.update { it.copy(preview = null, previewStoryHash = null) }
        }

        private fun action(block: suspend () -> Unit) {
            if (state.value.busy) return
            mutable.update { it.copy(busy = true, error = null, notice = null) }
            viewModelScope.launch {
                try {
                    block()
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (error: Exception) {
                    mutable.update { it.copy(error = error.message ?: "Please try again.") }
                } finally {
                    mutable.update { it.copy(busy = false) }
                }
            }
        }

        fun news(
            query: String = state.value.newsQuery,
            topic: String = "",
            language: String = state.value.language,
            category: String = state.value.newsCategory,
        ) {
            saved["newsQuery"] = query
            saved["newsTopic"] = topic
            saved["language"] = language
            saved["newsCategory"] = category
            mutable.update { it.copy(newsQuery = query, newsTopic = topic, newsCategory = category, language = language) }
        }

        fun addNews() =
            action {
                val current = state.value
                val params = mutableMapOf("language" to current.language)
                if (current.newsQuery.isNotBlank()) params["query"] = current.newsQuery.trim() else params["topic"] = current.newsTopic
                val url = request("/discover/google-news/feed", params).string("feed_url")
                if (url.isBlank()) throw IOException("Choose a topic or enter a search query.")
                addUrl(url)
            }

        fun webEdit(change: (WebDiscoveryState) -> WebDiscoveryState) {
            mutable.update { it.copy(web = change(it.web)) }
            saved["webUrl"] = state.value.web.url
            saved["webHint"] = state.value.web.hint
        }

        fun analyze() {
            val snapshot = state.value.web
            if (snapshot.url.isBlank() || state.value.busy) return
            webJob?.cancel()
            val token = ++webGeneration
            val id = UUID.randomUUID().toString()
            webEdit {
                it.copy(
                    loading = true,
                    analyzedUrl = snapshot.url.trim(),
                    requestId = id,
                    variants = emptyList(),
                    detectedFeed = "",
                    message = "Analyzing web page…",
                    error = null,
                )
            }
            webJob =
                viewModelScope.launch {
                    try {
                        val json =
                            request(
                                "/webfeed/analyze",
                                mapOf(
                                    "url" to snapshot.url.trim(),
                                    "request_id" to id,
                                    "story_hint" to snapshot.hint.take(200),
                                ),
                                true,
                            )
                        if (token != webGeneration) return@launch
                        if (json.number("code") == 2) {
                            webEdit {
                                it.copy(
                                    loading = false,
                                    detectedFeed =
                                        json.string("feed_address").ifBlank {
                                            snapshot.url.trim()
                                        },
                                    message = "This page already has an RSS feed.",
                                )
                            }
                            return@launch
                        }
                        withTimeout(120_000) {
                            repeat(40) {
                                delay(3000)
                                val status = request("/webfeed/status", mapOf("request_id" to id))
                                if (token != webGeneration) return@withTimeout
                                when (status.string("type").ifBlank { status.string("status") }) {
                                    "error" -> throw IOException(status.string("error").ifBlank { status.string("message") })
                                    "variants", "complete" -> {
                                        val data = status.obj("variants_data") ?: status
                                        val variants = data.objects("variants").map(WebVariant::parse)
                                        if (variants.isEmpty()) throw IOException("No story patterns found. Try a page that lists articles.")
                                        webEdit {
                                            it.copy(
                                                loading = false,
                                                variants = variants,
                                                selected = 0,
                                                title =
                                                    data.string("page_title").ifBlank {
                                                        data.string("feed_title")
                                                    },
                                                htmlHash =
                                                    data.string(
                                                        "html_hash",
                                                    ),
                                                favicon = data.string("favicon_url"),
                                                message = "Choose the stories to follow",
                                            )
                                        }
                                        return@withTimeout
                                    }
                                    else -> webEdit { it.copy(message = status.string("message").ifBlank { "Analyzing web page…" }) }
                                }
                            }
                            throw IOException("Analysis timed out. Please try again.")
                        }
                    } catch (_: TimeoutCancellationException) {
                        if (token == webGeneration) webEdit { it.copy(loading = false, error = "Analysis timed out. Please try again.", message = "") }
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (error: Exception) {
                        if (token ==
                            webGeneration
                        ) {
                            webEdit { it.copy(loading = false, error = error.message, message = "") }
                        }
                    }
                }
        }

        fun subscribeWeb() =
            action {
                val web = state.value.web
                val variant = web.variants.getOrNull(web.selected) ?: return@action
                val folder = selectedFolder()
                // DiscoveryViewModel.kt: webfeed/subscribe only accepts a leaf folder, so reject ambiguous destinations.
                val leaf = FolderPath.leaf(folder)
                if (state.value.folders.count { it.name.equals(leaf, ignoreCase = true) } >
                    1
                ) {
                    throw IOException("Choose a uniquely named folder for this web feed.")
                }
                val params =
                    variant.paths +
                        mapOf(
                            "url" to web.analyzedUrl,
                            "request_id" to web.requestId,
                            "variant_index" to "${web.selected}",
                            "feed_title" to web.title,
                            "html_hash" to web.htmlHash,
                            "favicon_url" to web.favicon,
                            "staleness_days" to "${web.staleness}",
                            "mark_unread_on_change" to "${web.markUnread}",
                            "folder" to leaf,
                        )
                val response = request("/webfeed/subscribe", params, true)
                if (response.number("code") <= 0) throw IOException(response.string("message").ifBlank { "Couldn’t create this web feed." })
                added("webfeed:${web.analyzedUrl}")
            }

        private suspend fun request(
            path: String,
            params: Map<String, String> = emptyMap(),
            post: Boolean = false,
        ) = withContext(workerDispatcher) {
            api.request(path, params, post)
        }

        companion object {
            const val TAB = "tab"
            const val FOLDER = "folder"

            internal fun isAddress(query: String) = query.contains("://") || (!query.contains(' ') && query.contains('.'))
        }
    }
