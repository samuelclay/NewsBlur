package com.newsblur.onboarding

import android.content.Context
import android.net.Uri
import com.google.gson.Gson
import com.newsblur.discover.DiscoveryFeed
import com.newsblur.discover.number
import com.newsblur.discover.objects
import com.newsblur.discover.string
import com.newsblur.service.SyncServiceState
import com.newsblur.service.NbSyncManager
import com.newsblur.service.NBSync
import com.newsblur.util.FeedUtils
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

data class SetupFailure(
    val folder: String,
    val feeds: List<DiscoveryFeed>,
    val existing: Boolean,
    val message: String,
)

data class SetupProgress(
    val queued: Set<String> = emptySet(),
    val added: Set<String> = emptySet(),
    val folders: Map<String, List<DiscoveryFeed>> = emptyMap(),
    val categories: Map<String, Set<String>> = emptyMap(),
    val failures: List<SetupFailure> = emptyList(),
    val importing: Boolean = false,
    val importMessage: String? = null,
    val importError: String? = null,
)

// SetupQueue.kt owns work beyond the sheet lifetime, and never continues it in a different login session.
@Singleton
class SetupQueue
    @Inject
    constructor(
        private val api: OnboardingApi,
        private val sync: SyncServiceState,
        @ApplicationContext private val context: Context,
    ) {
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        private val mutable = MutableStateFlow(SetupProgress())
        val state = mutable.asStateFlow()
        private var owner: SetupAccount? = null
        private var tail: Job? = null
        private var importJob: Job? = null
        private var batchSupported: Boolean? = null
        private var awaitingRenderedFeeds = false
        private var metadataReceived = false

        fun isPending(): Boolean =
            owner?.let { api.isCurrent(it) } == true &&
                (
                    mutable.value.queued.isNotEmpty() ||
                        mutable.value.importing ||
                        awaitingRenderedFeeds
                )

        init {
            scope.launch {
                state.collect {
                    com.newsblur.service.NbSyncManager
                        .submitUpdate(com.newsblur.service.NbSyncManager.UPDATE_STATUS)
                }
            }
            scope.launch {
                NbSyncManager.state.collect { event ->
                    if (event is NBSync.Update && event.type and NbSyncManager.UPDATE_METADATA != 0 && !sync.doFeedsFolders) {
                        metadataRefreshed()
                    } else if (event is NBSync.Error) {
                        awaitingRenderedFeeds = false
                    }
                }
            }
        }

        fun bind(account: SetupAccount) {
            if (owner == account) return
            tail?.cancel()
            importJob?.cancel()
            owner = account
            batchSupported = null
            awaitingRenderedFeeds = false
            metadataReceived = false
            mutable.value = SetupProgress()
        }

        fun refresh() {
            if (owner?.let(api::isCurrent) != true) return
            awaitingRenderedFeeds = true
            metadataReceived = false
            sync.forceFeedsFolders()
            FeedUtils.triggerSync(context)
            NbSyncManager.submitUpdate(NbSyncManager.UPDATE_STATUS)
        }

        // SetupQueue.kt waits for Main's cursor callback, not merely the network response.
        fun metadataRefreshed() {
            if (!sync.doFeedsFolders) metadataReceived = true
        }

        fun feedListRendered() {
            if (!awaitingRenderedFeeds || !metadataReceived || sync.doFeedsFolders) return
            awaitingRenderedFeeds = false
            NbSyncManager.submitUpdate(NbSyncManager.UPDATE_STATUS)
        }

        private fun imported(folders: Map<String, List<DiscoveryFeed>>) {
            val old = mutable.value
            mutable.value = old.copy(added = old.added + folders.values.flatten().map { it.url }, folders = merge(old.folders, folders))
            refresh()
        }

        fun import(uri: Uri) {
            val account = owner ?: return
            if (!api.isCurrent(account) || importJob?.isActive == true) return
            mutable.value = mutable.value.copy(importing = true, importMessage = null, importError = null)
            importJob =
                scope.launch {
                    try {
                        val (bytes, receipt) =
                            withContext(Dispatchers.IO) {
                                val data =
                                    context.contentResolver.openInputStream(uri)?.use(SetupOpml::read)
                                        ?: error("Could not open this file.")
                                data to SetupOpml.parse(data)
                            }
                        if (!api.isCurrent(account)) return@launch
                        api.import(bytes, account)
                        if (!api.isCurrent(account)) return@launch
                        imported(receipt)
                        mutable.value =
                            mutable.value.copy(importMessage = "Import queued. Your feeds and folders will appear as they are processed.")
                    } catch (cancel: CancellationException) {
                        throw cancel
                    } catch (e: Exception) {
                        if (api.isCurrent(account)) {
                            mutable.value =
                                mutable.value.copy(importError = e.message ?: "Could not import this file.")
                        }
                    } finally {
                        if (owner == account) mutable.value = mutable.value.copy(importing = false)
                    }
                }
        }

        private fun merge(
            old: Map<String, List<DiscoveryFeed>>,
            added: Map<String, List<DiscoveryFeed>>,
        ) = (old.keys + added.keys).associateWith {
            ((old[it] ?: emptyList()) + (added[it] ?: emptyList())).distinctBy { feed ->
                feed.url
            }
        }

        fun retry(failure: SetupFailure) {
            enqueue(failure.feeds, failure.folder, existing = failure.existing)
        }

        fun enqueue(
            feeds: List<DiscoveryFeed>,
            folder: String,
            category: String? = null,
            existing: Boolean = false,
        ) {
            val account = owner ?: return
            if (!api.isCurrent(account)) return
            val old = mutable.value
            val chosen = feeds.distinctBy { it.url }.filter { it.url !in old.added && it.url !in old.queued }
            if (chosen.isEmpty()) return
            val urls = chosen.map { it.url }.toSet()
            mutable.value =
                old.copy(
                    queued = old.queued + urls,
                    folders = merge(old.folders, mapOf(folder to chosen)),
                    categories =
                        if (category ==
                            null
                        ) {
                            old.categories
                        } else {
                            old.categories + (category to (old.categories[category].orEmpty() + urls))
                        },
                    failures =
                        old.failures.mapNotNull { failure ->
                            failure.copy(feeds = failure.feeds.filter { it.url !in urls }).takeIf { it.feeds.isNotEmpty() }
                        },
                )
            val previous = tail
            tail =
                scope.launch {
                    previous?.join()
                    if (!api.isCurrent(account)) return@launch
                    val failed = mutableListOf<DiscoveryFeed>()
                    var error = "Some feeds could not be added. Please retry."
                    val fields =
                        if (existing) {
                            mapOf("folder_path" to Gson().toJson(folder.split(" ▸ ").filter { it.isNotBlank() }))
                        } else {
                            mapOf("folder_path" to "[]", "new_folder" to folder)
                        }
                    val known = chosen.filter { it.id.toLongOrNull()?.let { id -> id > 0 } == true }
                    var individual = chosen
                    try {
                        if (known.isNotEmpty()) {
                            if (batchSupported ==
                                null
                            ) {
                                batchSupported =
                                    api
                                        .request(
                                            "/reader/add_feeds",
                                            account = account,
                                            allowMissing = true,
                                        )?.json
                                        ?.string("batch_add_supported") ==
                                    "true"
                            }
                            check(api.isCurrent(account))
                            if (batchSupported == true) {
                                val response =
                                    api.request(
                                        "/reader/add_feeds",
                                        fields + (
                                            "feed_ids" to
                                                Gson().toJson(
                                                    known.map {
                                                        it.id.toLong()
                                                    },
                                                )
                                        ),
                                        true,
                                        account,
                                        allowMissing = true,
                                    )
                                if (response != null) {
                                    val accepted =
                                        response.json
                                            .objects(
                                                "results",
                                            ).filter { it.number("code") == 1 }
                                            .map { it.string("feed_id") }
                                            .toSet()
                                    known.forEach { if (it.id in accepted) success(it, account) else failed.add(it) }
                                    individual = chosen - known.toSet()
                                } else {
                                    batchSupported = false
                                }
                            }
                        }
                    } catch (cancel: CancellationException) {
                        throw cancel
                    } catch (exception: Exception) {
                        // SetupQueue.kt never retries an ambiguous batch write through add_url.
                        failed.addAll(known)
                        individual = chosen - known.toSet()
                        error = exception.message ?: error
                    }
                    for (feed in individual) {
                        if (!api.isCurrent(account)) return@launch
                        try {
                            api.request("/reader/add_url", fields + ("url" to feed.url), true, account)
                            success(feed, account)
                        } catch (cancel: CancellationException) {
                            throw cancel
                        } catch (exception: Exception) {
                            failed.add(feed)
                            error =
                                exception.message ?: error
                        }
                    }
                    if (!api.isCurrent(account)) return@launch
                    refresh()
                    val current = mutable.value
                    mutable.value =
                        current.copy(
                            queued = current.queued - urls,
                            failures =
                                current.failures +
                                    if (failed.isEmpty()) emptyList() else listOf(SetupFailure(folder, failed, existing, error)),
                        )
                }
        }

        private fun success(
            feed: DiscoveryFeed,
            account: SetupAccount,
        ) {
            if (!api.isCurrent(account)) return
            mutable.value = mutable.value.copy(added = mutable.value.added + feed.url, queued = mutable.value.queued - feed.url)
        }
    }
