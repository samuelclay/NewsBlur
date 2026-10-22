package com.newsblur.listen

import android.content.Context
import androidx.annotation.OptIn
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import com.newsblur.network.ListenApi
import com.newsblur.network.ListenLibraryQuery
import com.newsblur.network.ListenVoicePreviewRequest
import com.newsblur.preference.ListenDelivery
import com.newsblur.preference.ListenPrefKeys
import com.newsblur.preference.ListenPreferences
import com.newsblur.preference.ListenSettings
import com.newsblur.preference.ListenVoiceSettings
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Locale
import javax.inject.Inject

/** The "More voices" part of the picker: GET /listen/library pages for the current filters and search. */
data class ListenLibraryState(
    val voices: List<ListenVoice> = emptyList(),
    val page: Int = 0,
    val hasMore: Boolean = false,
    val loading: Boolean = false,
    val error: ListenError? = null,
)

/**
 * ListenVoiceSettingsViewModel.kt filters the picker the same way as the web: one value per category, and a search
 * across the name, description, accent, style and use case. Recommended voices are filtered here; the library is
 * filtered by the server with the same values.
 */
object ListenVoiceMatching {
    val FILTER_KEYS =
        listOf(
            ListenFilters.KEY_GENDER,
            ListenFilters.KEY_AGE,
            ListenFilters.KEY_ACCENT,
            ListenFilters.KEY_DESCRIPTIVE,
        )

    fun value(
        voice: ListenVoice,
        key: String,
    ): String? =
        when (key) {
            ListenFilters.KEY_GENDER -> voice.gender
            ListenFilters.KEY_AGE -> voice.age
            ListenFilters.KEY_ACCENT -> voice.accent
            ListenFilters.KEY_DESCRIPTIVE -> voice.descriptive
            ListenFilters.KEY_USE_CASE -> voice.useCase
            else -> null
        }

    fun matches(
        voice: ListenVoice,
        filters: Map<String, String>,
        search: String,
    ): Boolean {
        if (!filters.all { (key, wanted) -> value(voice, key) == wanted }) return false
        val query = search.trim().lowercase(Locale.ROOT)
        if (query.isEmpty()) return true
        val haystack =
            listOfNotNull(voice.name, voice.description, voice.accent, voice.descriptive, voice.useCase)
                .joinToString(" ")
                .lowercase(Locale.ROOT)
        return query in haystack
    }

    /** A voice picked from the library stays listed at the top of the recommendations for its language. */
    fun recommended(
        curated: List<ListenVoice>,
        selected: ListenVoice?,
    ): List<ListenVoice> = if (selected == null || curated.any { it.voiceId == selected.voiceId }) curated else listOf(selected) + curated

    /** Library voices not already shown among the recommendations. */
    fun more(
        library: List<ListenVoice>,
        recommended: List<ListenVoice>,
    ): List<ListenVoice> {
        val shown = recommended.map { it.voiceId }.toSet()
        return library.filter { it.voiceId !in shown }.distinctBy { it.voiceId }
    }
}

data class ListenVoiceSettingsUiState(
    val loading: Boolean = true,
    val error: ListenError? = null,
    val languages: List<ListenLanguage> = emptyList(),
    val language: String = DEFAULT_LANGUAGE,
    val curated: List<ListenVoice> = emptyList(),
    val selectedVoiceId: String? = null,
    val deliveryPresets: List<ListenDeliveryPreset> = emptyList(),
    val filters: ListenFilters = ListenFilters(),
    val settings: ListenSettings = ListenSettings(),
    val activeFilters: Map<String, String> = emptyMap(),
    val search: String = "",
    val library: ListenLibraryState = ListenLibraryState(),
    val knownVoices: Map<String, ListenVoice> = emptyMap(),
    val previewingVoiceId: String? = null,
    val previewLoadingVoiceId: String? = null,
    val previewError: ListenError? = null,
    val usage: ListenUsage? = null,
) {
    val languageName: String
        get() = languages.firstOrNull { it.code == language }?.name ?: language

    val hasFilters: Boolean
        get() = activeFilters.isNotEmpty() || search.isNotBlank()

    private val allRecommended: List<ListenVoice>
        get() {
            val selected = selectedVoiceId?.let { knownVoices[it] }?.takeIf { it.language == null || it.language == language }
            return ListenVoiceMatching.recommended(curated, selected)
        }

    val recommended: List<ListenVoice>
        get() = allRecommended.filter { ListenVoiceMatching.matches(it, activeFilters, search) }

    val moreVoices: List<ListenVoice>
        get() = ListenVoiceMatching.more(library.voices, allRecommended)

    /** The slider values to show: a preset's own values, or the saved custom ones. */
    val voiceSettings: ListenVoiceSettings
        get() {
            if (settings.delivery == ListenDelivery.CUSTOM) {
                return ListenVoiceSettings(settings.stability, settings.similarity, settings.style)
            }
            deliveryPresets.firstOrNull { it.id == settings.delivery.value }?.let {
                return ListenVoiceSettings(it.stability, it.similarity, it.style)
            }
            return ListenVoiceSettings.forPreset(settings.delivery)
                ?: ListenVoiceSettings(settings.stability, settings.similarity, settings.style)
        }

    companion object {
        const val DEFAULT_LANGUAGE = "en"
    }
}

/**
 * ListenVoiceSettingsViewModel.kt backs the voice picker: recommended voices for a language and the whole library
 * below them under one set of filters, voice previews read from the current story, delivery, speed and the other
 * Listen settings. Choices are saved to the synced server preferences, and a story playing in that language
 * restarts in the new voice.
 */
@OptIn(UnstableApi::class)
@HiltViewModel
class ListenVoiceSettingsViewModel
    @Inject
    constructor(
        @param:ApplicationContext private val context: Context,
        private val listenApi: ListenApi,
        private val listenPreferences: ListenPreferences,
        private val listenManager: ListenManager,
    ) : ViewModel() {
        private val mutableState =
            MutableStateFlow(ListenVoiceSettingsUiState(settings = listenPreferences.current()))
        val state: StateFlow<ListenVoiceSettingsUiState> = mutableState.asStateFlow()

        private var storyHash: String? = null
        private var initialized = false
        private var voicesJob: Job? = null
        private var libraryJob: Job? = null
        private var searchJob: Job? = null
        private var previewJob: Job? = null
        private var previewPlayer: ExoPlayer? = null

        init {
            viewModelScope.launch {
                listenPreferences.settings.collect { settings ->
                    mutableState.update { it.copy(settings = settings) }
                }
            }
        }

        fun initialize(
            storyHash: String?,
            language: String?,
        ) {
            if (initialized) return
            initialized = true
            this.storyHash = storyHash
            val start = language?.takeIf { it.isNotBlank() } ?: ListenVoiceSettingsUiState.DEFAULT_LANGUAGE
            mutableState.update { it.copy(language = start) }
            loadVoices(start)
            loadLibrary(reset = true)
        }

        fun selectLanguage(language: String) {
            if (language == state.value.language && !state.value.loading) return
            // Accents differ by language, so an accent filter doesn't carry over.
            mutableState.update {
                it.copy(
                    language = language,
                    activeFilters = it.activeFilters - ListenFilters.KEY_ACCENT,
                    curated = emptyList(),
                    library = ListenLibraryState(),
                )
            }
            loadVoices(language)
            loadLibrary(reset = true)
        }

        fun retry() {
            loadVoices(state.value.language)
            loadLibrary(reset = true)
        }

        private fun loadVoices(language: String) {
            voicesJob?.cancel()
            mutableState.update { it.copy(loading = true, error = null) }
            voicesJob =
                viewModelScope.launch {
                    when (val result = listenApi.getVoices(language)) {
                        is ListenResult.Failure ->
                            mutableState.update { it.copy(loading = false, error = result.error) }
                        is ListenResult.Success -> {
                            val response = result.value
                            val localChoice = listenPreferences.current().voiceFor(language)
                            val curated = response.voices[language].orEmpty()
                            mutableState.update {
                                it.copy(
                                    loading = false,
                                    languages = response.languages.ifEmpty { it.languages },
                                    curated = curated,
                                    selectedVoiceId =
                                        localChoice ?: response.selected[language] ?: response.defaults[language],
                                    deliveryPresets = response.deliveryPresets.ifEmpty { it.deliveryPresets },
                                    filters = ListenFilters.parse(response.filters),
                                    usage = response.usage ?: it.usage,
                                    knownVoices = it.knownVoices + curated.associateBy { voice -> voice.voiceId },
                                )
                            }
                        }
                    }
                }
        }

        fun selectVoice(voice: ListenVoice) {
            val language = state.value.language
            mutableState.update {
                it.copy(selectedVoiceId = voice.voiceId, knownVoices = it.knownVoices + (voice.voiceId to voice))
            }
            viewModelScope.launch {
                listenPreferences.save(listenPreferences.voiceChange(language, voice.voiceId))
                restartIfPlaying(language)
            }
        }

        fun selectDelivery(delivery: ListenDelivery) {
            if (delivery == ListenDelivery.CUSTOM) {
                saveCustom(state.value.voiceSettings, state.value.settings.speakerBoost)
                return
            }
            viewModelScope.launch {
                listenPreferences.save(mapOf(ListenPrefKeys.DELIVERY to delivery.value))
                restartIfPlaying(language = null)
            }
        }

        /** Slider drags show right away; the custom delivery is saved when the drag ends. */
        fun previewCustom(settings: ListenVoiceSettings) {
            mutableState.update {
                it.copy(
                    settings =
                        it.settings.copy(
                            delivery = ListenDelivery.CUSTOM,
                            stability = settings.stability,
                            similarity = settings.similarity,
                            style = settings.style,
                        ),
                )
            }
        }

        fun saveCustom(
            settings: ListenVoiceSettings,
            speakerBoost: Boolean,
        ) {
            viewModelScope.launch {
                listenPreferences.save(
                    mapOf(
                        ListenPrefKeys.DELIVERY to ListenDelivery.CUSTOM.value,
                        ListenPrefKeys.STABILITY to settings.stability,
                        ListenPrefKeys.SIMILARITY to settings.similarity,
                        ListenPrefKeys.STYLE to settings.style,
                        ListenPrefKeys.SPEAKER_BOOST to speakerBoost,
                    ),
                )
                restartIfPlaying(language = null)
            }
        }

        fun setSpeed(speed: Double) = listenManager.setSpeed(speed)

        fun setAutoContinue(enabled: Boolean) = listenPreferences.saveInBackground(mapOf(ListenPrefKeys.AUTO_CONTINUE to enabled))

        fun setHighlight(enabled: Boolean) = listenPreferences.saveInBackground(mapOf(ListenPrefKeys.HIGHLIGHT to enabled))

        private fun restartIfPlaying(language: String?) {
            val playing = listenManager.state.value
            if (!playing.isActive || playing.phase == ListenPhase.ENDED || playing.phase == ListenPhase.PREVIEW_ENDED) return
            if (language != null && playing.language != language) return
            listenManager.restartWithCurrentSettings()
        }

        // region Filters and the library

        fun setFilter(
            key: String,
            value: String?,
        ) {
            mutableState.update {
                it.copy(activeFilters = if (value.isNullOrBlank()) it.activeFilters - key else it.activeFilters + (key to value))
            }
            loadLibrary(reset = true)
        }

        fun clearFilters() {
            searchJob?.cancel()
            mutableState.update { it.copy(activeFilters = emptyMap(), search = "") }
            loadLibrary(reset = true)
        }

        fun setSearch(search: String) {
            mutableState.update { it.copy(search = search) }
            searchJob?.cancel()
            searchJob =
                viewModelScope.launch {
                    delay(SEARCH_DEBOUNCE_MS)
                    loadLibrary(reset = true)
                }
        }

        /** Called as the list nears its end: the next page of the library, for infinite scrolling. */
        fun loadMore() {
            val library = state.value.library
            if (library.loading || !library.hasMore || library.error != null) return
            loadLibrary(reset = false)
        }

        fun retryLibrary() =
            loadLibrary(
                reset =
                    state.value.library.voices
                        .isEmpty(),
            )

        private fun loadLibrary(reset: Boolean) {
            libraryJob?.cancel()
            val current = state.value
            val page = if (reset) 0 else current.library.page + 1
            mutableState.update {
                it.copy(
                    library =
                        it.library.copy(
                            loading = true,
                            error = null,
                            voices = if (reset) emptyList() else it.library.voices,
                            hasMore = if (reset) false else it.library.hasMore,
                        ),
                )
            }
            libraryJob =
                viewModelScope.launch {
                    val query =
                        ListenLibraryQuery(
                            language = current.language,
                            filters = current.activeFilters,
                            search = current.search,
                            page = page,
                        )
                    when (val result = listenApi.getLibrary(query)) {
                        is ListenResult.Failure ->
                            mutableState.update { it.copy(library = it.library.copy(loading = false, error = result.error)) }
                        is ListenResult.Success ->
                            mutableState.update {
                                val voices = if (reset) result.value.voices else it.library.voices + result.value.voices
                                it.copy(
                                    library =
                                        it.library.copy(
                                            loading = false,
                                            voices = voices.distinctBy { voice -> voice.voiceId },
                                            page = result.value.page,
                                            hasMore = result.value.hasMore,
                                        ),
                                    knownVoices = it.knownVoices + result.value.voices.associateBy { voice -> voice.voiceId },
                                )
                            }
                    }
                }
        }

        // endregion

        // region Voice previews

        fun togglePreview(voice: ListenVoice) {
            if (state.value.previewingVoiceId == voice.voiceId || state.value.previewLoadingVoiceId == voice.voiceId) {
                stopPreview()
                return
            }
            stopPreview()
            // A voice preview pauses the story rather than talking over it.
            if (listenManager.state.value.playWhenReady) listenManager.setPlayWhenReady(false)
            val hash = storyHash
            val directUrl = voice.previewUrl?.takeIf { it.isNotBlank() }
            if (hash == null && directUrl != null) {
                playPreview(voice.voiceId, directUrl)
                return
            }
            mutableState.update { it.copy(previewLoadingVoiceId = voice.voiceId, previewError = null) }
            previewJob =
                viewModelScope.launch {
                    val settings = state.value.settings
                    val custom = settings.delivery == ListenDelivery.CUSTOM
                    val result =
                        listenApi.getVoicePreview(
                            ListenVoicePreviewRequest(
                                voiceId = voice.voiceId,
                                storyHash = hash,
                                language = state.value.language,
                                delivery = settings.delivery.value,
                                stability = if (custom) settings.stability else null,
                                similarity = if (custom) settings.similarity else null,
                                style = if (custom) settings.style else null,
                                speakerBoost = if (custom) settings.speakerBoost else null,
                            ),
                        )
                    when (result) {
                        is ListenResult.Failure -> {
                            // Without a server preview, the voice's own sample still lets people hear it.
                            if (directUrl != null && result.error.reason != ListenError.REASON_PREVIEW_LIMIT) {
                                playPreview(voice.voiceId, directUrl)
                            } else {
                                mutableState.update {
                                    it.copy(
                                        previewLoadingVoiceId = null,
                                        previewError = result.error,
                                        usage = result.error.usage ?: it.usage,
                                    )
                                }
                            }
                        }
                        is ListenResult.Success -> {
                            val url = result.value.url?.takeIf { it.isNotBlank() }
                            mutableState.update { it.copy(usage = result.value.usage ?: it.usage) }
                            if (url == null) {
                                mutableState.update { it.copy(previewLoadingVoiceId = null) }
                            } else {
                                playPreview(voice.voiceId, listenApi.resolveAudioUrl(url))
                            }
                        }
                    }
                }
        }

        private fun playPreview(
            voiceId: String,
            url: String,
        ) {
            val player = previewPlayer ?: createPreviewPlayer().also { previewPlayer = it }
            player.setMediaItem(MediaItem.fromUri(url))
            player.prepare()
            player.play()
            mutableState.update { it.copy(previewLoadingVoiceId = null, previewingVoiceId = voiceId, previewError = null) }
        }

        fun stopPreview() {
            previewJob?.cancel()
            previewPlayer?.stop()
            mutableState.update { it.copy(previewingVoiceId = null, previewLoadingVoiceId = null) }
        }

        private fun createPreviewPlayer(): ExoPlayer {
            val http =
                DefaultHttpDataSource
                    .Factory()
                    .setUserAgent(listenApi.audioUserAgent)
                    .setAllowCrossProtocolRedirects(true)
            return ExoPlayer
                .Builder(context)
                .setMediaSourceFactory(DefaultMediaSourceFactory(DefaultDataSource.Factory(context, http)))
                .setAudioAttributes(ListenSessionPlayer.AUDIO_ATTRIBUTES, true)
                .build()
                .apply {
                    addListener(
                        object : Player.Listener {
                            override fun onPlaybackStateChanged(playbackState: Int) {
                                if (playbackState == Player.STATE_ENDED) {
                                    mutableState.update { it.copy(previewingVoiceId = null) }
                                }
                            }

                            override fun onPlayerError(error: PlaybackException) {
                                mutableState.update {
                                    it.copy(
                                        previewingVoiceId = null,
                                        previewLoadingVoiceId = null,
                                        previewError = ListenError(ListenError.REASON_PLAYBACK, null),
                                    )
                                }
                            }
                        },
                    )
                }
        }

        // endregion

        override fun onCleared() {
            previewPlayer?.release()
            previewPlayer = null
            super.onCleared()
        }

        companion object {
            private const val SEARCH_DEBOUNCE_MS = 400L

            private val LISTEN_LANGUAGES =
                setOf(
                    "en",
                    "es",
                    "fr",
                    "de",
                    "pt-BR",
                    "it",
                    "nl",
                    "pl",
                    "tr",
                    "ru",
                    "uk",
                    "ar",
                    "he",
                    "hi",
                    "id",
                    "vi",
                    "th",
                    "ja",
                    "ko",
                    "zh-Hans",
                    "zh-Hant",
                )

            /** Opening voice settings outside a story starts on the device's language, when Listen supports it. */
            fun languageFor(locale: Locale): String {
                val candidate =
                    when (val language = locale.language) {
                        "pt" -> "pt-BR"
                        // Older Android reports Hebrew and Indonesian with their legacy codes.
                        "iw" -> "he"
                        "in" -> "id"
                        "zh" ->
                            if (locale.script == "Hant" || locale.country in setOf("TW", "HK", "MO")) "zh-Hant" else "zh-Hans"
                        else -> language
                    }
                return if (candidate in LISTEN_LANGUAGES) candidate else ListenVoiceSettingsUiState.DEFAULT_LANGUAGE
            }
        }
    }
