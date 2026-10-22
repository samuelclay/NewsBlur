package com.newsblur.preference

import android.content.SharedPreferences
import android.os.SystemClock
import androidx.core.content.edit
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.JsonPrimitive
import com.newsblur.listen.ListenSpeed
import com.newsblur.network.UserApi
import com.newsblur.util.Log
import com.newsblur.util.NBScope
import com.newsblur.util.PrefConstants
import com.newsblur.util.StoryButton
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject
import javax.inject.Singleton

/** ListenPreferences.kt uses the server's preference names locally too, so syncing needs no translation. */
object ListenPrefKeys {
    const val VOICES = "listen_voices"
    const val DELIVERY = "listen_delivery"
    const val STABILITY = "listen_stability"
    const val SIMILARITY = "listen_similarity"
    const val STYLE = "listen_style"
    const val SPEAKER_BOOST = "listen_speaker_boost"
    const val SPEED = "listen_speed"
    const val AUTO_CONTINUE = "listen_auto_continue"
    const val HIGHLIGHT = "listen_highlight"

    val booleans = setOf(SPEAKER_BOOST, AUTO_CONTINUE, HIGHLIGHT)
    val doubles = setOf(STABILITY, SIMILARITY, STYLE, SPEED)
    val strings = setOf(DELIVERY)
}

enum class ListenDelivery(
    val value: String,
) {
    STEADY("steady"),
    NATURAL("natural"),
    EXPRESSIVE("expressive"),
    CUSTOM("custom"),
    ;

    companion object {
        val presets = listOf(STEADY, NATURAL, EXPRESSIVE)

        fun fromValue(value: String?): ListenDelivery = entries.firstOrNull { it.value == value } ?: NATURAL
    }
}

/** ListenPreferences.kt's copy of the presets /listen/voices returns, used until that response arrives. */
data class ListenVoiceSettings(
    val stability: Double,
    val similarity: Double,
    val style: Double,
) {
    companion object {
        fun forPreset(delivery: ListenDelivery): ListenVoiceSettings? =
            when (delivery) {
                ListenDelivery.STEADY -> ListenVoiceSettings(0.75, 0.75, 0.0)
                ListenDelivery.NATURAL -> ListenVoiceSettings(0.5, 0.75, 0.0)
                ListenDelivery.EXPRESSIVE -> ListenVoiceSettings(0.3, 0.75, 0.35)
                ListenDelivery.CUSTOM -> null
            }
    }
}

data class ListenSettings(
    val voices: Map<String, String> = emptyMap(),
    val delivery: ListenDelivery = ListenDelivery.NATURAL,
    val stability: Double = DEFAULT_STABILITY,
    val similarity: Double = DEFAULT_SIMILARITY,
    val style: Double = DEFAULT_STYLE,
    val speakerBoost: Boolean = true,
    val speed: Double = DEFAULT_SPEED,
    val autoContinue: Boolean = true,
    val highlight: Boolean = true,
) {
    fun voiceFor(language: String?): String? = language?.let { voices[it] }

    companion object {
        const val DEFAULT_STABILITY = 0.5
        const val DEFAULT_SIMILARITY = 0.75
        const val DEFAULT_STYLE = 0.0
        const val DEFAULT_SPEED = 1.0
        const val MIN_SPEED = 0.5
        const val MAX_SPEED = 3.0
    }
}

/** The preferences /reader/feeds returned, typed the way ListenPreferences.kt stores them. */
data class ServerPreferenceValues(
    val booleans: Map<String, Boolean> = emptyMap(),
    val doubles: Map<String, Double> = emptyMap(),
    val strings: Map<String, String> = emptyMap(),
) {
    val keys: Set<String>
        get() = booleans.keys + doubles.keys + strings.keys
}

/**
 * ListenPreferences.kt parses server preferences leniently: /profile/set_preference keeps every value as a
 * string except "true" and "false", while the web client may save real numbers and objects.
 */
object ListenPreferenceParser {
    fun booleanValue(element: JsonElement?): Boolean? {
        val primitive = element?.takeIf { it.isJsonPrimitive }?.asJsonPrimitive ?: return null
        return when {
            primitive.isBoolean -> primitive.asBoolean
            primitive.isNumber -> primitive.asDouble != 0.0
            primitive.isString ->
                when (primitive.asString.trim().lowercase()) {
                    "true", "1", "yes", "on" -> true
                    "false", "0", "no", "off" -> false
                    else -> null
                }
            else -> null
        }
    }

    fun doubleValue(element: JsonElement?): Double? {
        val primitive = element?.takeIf { it.isJsonPrimitive }?.asJsonPrimitive ?: return null
        val value =
            when {
                primitive.isNumber -> primitive.asDouble
                primitive.isString -> primitive.asString.trim().toDoubleOrNull()
                else -> null
            }
        return value?.takeIf { it.isFinite() }
    }

    fun stringValue(element: JsonElement?): String? {
        val primitive = element?.takeIf { it.isJsonPrimitive }?.asJsonPrimitive ?: return null
        return primitive.asString
    }

    /** listen_voices is a JSON-encoded string of {"<lang>": "<voice_id>"}, but an object is accepted too. */
    fun voicesValue(element: JsonElement?): Map<String, String>? {
        if (element == null || element.isJsonNull) return null
        val objectValue =
            when {
                element.isJsonObject -> element.asJsonObject
                element.isJsonPrimitive && element.asJsonPrimitive.isString ->
                    parseObject(
                        element.asString,
                    )
                else -> null
            } ?: return null
        return objectValue
            .entrySet()
            .mapNotNull { (language, voice) ->
                stringValue(voice)?.takeIf { it.isNotBlank() }?.let { language to it }
            }.toMap()
    }

    fun encodeVoices(voices: Map<String, String>): String {
        val json = JsonObject()
        voices.toSortedMap().forEach { (language, voiceId) ->
            json.add(language, JsonPrimitive(voiceId))
        }
        return json.toString()
    }

    fun parse(preferences: JsonObject?): ServerPreferenceValues {
        if (preferences == null) return ServerPreferenceValues()
        val booleans = linkedMapOf<String, Boolean>()
        val doubles = linkedMapOf<String, Double>()
        val strings = linkedMapOf<String, String>()
        (ListenPrefKeys.booleans + StoryButton.prefKeys).forEach { key ->
            booleanValue(preferences.get(key))?.let { booleans[key] = it }
        }
        ListenPrefKeys.doubles.forEach { key ->
            doubleValue(preferences.get(key))?.let { doubles[key] = clamp(key, it) }
        }
        stringValue(preferences.get(ListenPrefKeys.DELIVERY))?.let { delivery ->
            strings[ListenPrefKeys.DELIVERY] = ListenDelivery.fromValue(delivery).value
        }
        voicesValue(preferences.get(ListenPrefKeys.VOICES))?.let {
            strings[ListenPrefKeys.VOICES] =
                encodeVoices(it)
        }
        return ServerPreferenceValues(booleans, doubles, strings)
    }

    fun clamp(
        key: String,
        value: Double,
    ): Double =
        when (key) {
            ListenPrefKeys.SPEED -> ListenSpeed.clamp(value)
            else -> value.coerceIn(0.0, 1.0)
        }

    /** Like serverString, but listen_speed is always a decimal string with up to two places, like "1.05". */
    fun serverString(
        key: String,
        value: Any,
    ): String =
        if (key == ListenPrefKeys.SPEED && value is Number) {
            ListenSpeed.prefString(value.toDouble())
        } else {
            serverString(value)
        }

    /** Formats a value for /profile/set_preference, which turns only "true" and "false" into booleans. */
    fun serverString(value: Any): String =
        when (value) {
            is Boolean -> value.toString()
            is Double -> trimNumber(value)
            is Float -> trimNumber(value.toDouble())
            is Map<*, *> ->
                encodeVoices(
                    value.entries
                        .mapNotNull { (key, voice) ->
                            (key as? String)?.let { k ->
                                (voice as? String)?.let {
                                    k to
                                        it
                                }
                            }
                        }.toMap(),
                )
            else -> value.toString()
        }

    private fun trimNumber(value: Double): String {
        val rounded = Math.round(value * 1000.0) / 1000.0
        return if (rounded == rounded.toLong().toDouble()) {
            rounded.toLong().toString()
        } else {
            rounded.toString()
        }
    }

    private fun parseObject(raw: String): JsonObject? =
        try {
            JsonParser.parseString(raw).takeIf { it.isJsonObject }?.asJsonObject
        } catch (_: RuntimeException) {
            null
        }
}

/**
 * ListenPreferences.kt reads and writes the synced Listen settings and story button toggles. Local changes are
 * saved first and then sent to /profile/set_preference; a recent local change wins over an older server copy
 * that was already in flight from /reader/feeds.
 */
@Singleton
class ListenPreferences
    @Inject
    constructor(
        private val prefs: SharedPreferences,
        private val userApi: UserApi,
    ) {
        private val recentLocalChanges = ConcurrentHashMap<String, Long>()

        /** The clock that decides whether a local change is recent; Test_ListenPreferences.kt sets its own. */
        internal var elapsedRealtime: () -> Long = { SystemClock.elapsedRealtime() }
        private var speedSaveJob: Job? = null
        private val mutableSettings = MutableStateFlow(readSettings())
        val settings: StateFlow<ListenSettings> = mutableSettings.asStateFlow()

        // ListenPreferences.kt keeps a strong reference: SharedPreferences only holds listeners weakly.
        private val changeListener =
            SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
                if (key == null ||
                    key in ListenPrefKeys.booleans ||
                    key in ListenPrefKeys.doubles ||
                    key in ListenPrefKeys.strings ||
                    key == ListenPrefKeys.VOICES
                ) {
                    mutableSettings.value = readSettings()
                }
            }

        init {
            prefs.registerOnSharedPreferenceChangeListener(changeListener)
        }

        fun current(): ListenSettings = mutableSettings.value

        fun isStoryButtonVisible(button: StoryButton): Boolean =
            when (button) {
                // ListenPreferences.kt carries the old device-only Ask AI toggle forward until the server has one.
                StoryButton.ASK_AI ->
                    prefs.getBoolean(
                        button.prefKey,
                        prefs.getBoolean(PrefConstants.SHOW_ASK_AI, true),
                    )
                else -> prefs.getBoolean(button.prefKey, true)
            }

        fun setStoryButtonVisible(
            button: StoryButton,
            visible: Boolean,
        ) = saveInBackground(mapOf(button.prefKey to visible))

        /** Saves locally right away, then on the server. Returns whether the server accepted the change. */
        suspend fun save(values: Map<String, Any>): Boolean {
            if (values.isEmpty()) return true
            saveLocally(values)
            return saveRemotely(values)
        }

        /** Saves locally now and sends the change to the server without waiting for it. */
        fun saveInBackground(values: Map<String, Any>) {
            if (values.isEmpty()) return
            saveLocally(values)
            NBScope.launch { saveRemotely(values) }
        }

        /**
         * Applies a speed locally at once, so every screen follows the slider, and sends it to the server once
         * the speed has held still for a moment instead of on every step.
         */
        fun saveSpeed(speed: Double) {
            val value = ListenSpeed.clamp(speed)
            saveLocally(mapOf(ListenPrefKeys.SPEED to value))
            speedSaveJob?.cancel()
            speedSaveJob =
                NBScope.launch {
                    delay(SPEED_SAVE_DEBOUNCE_MS)
                    saveRemotely(mapOf(ListenPrefKeys.SPEED to value))
                }
        }

        private fun saveLocally(values: Map<String, Any>) {
            writeLocal(values)
            val now = elapsedRealtime()
            values.keys.forEach { recentLocalChanges[it] = now }
        }

        private suspend fun saveRemotely(values: Map<String, Any>): Boolean {
            val saved =
                try {
                    // NetworkClient.kt blocks while it retries, so the request stays off the main thread.
                    withContext(Dispatchers.IO) {
                        userApi.setPreferences(
                            values.mapValues { (key, value) ->
                                ListenPreferenceParser.serverString(key, value)
                            },
                        )
                    }
                } catch (error: java.io.IOException) {
                    Log.w(this.javaClass.name, "Listen preference save failed: ${error.message}")
                    false
                }
            if (!saved) {
                Log.w(
                    this.javaClass.name,
                    "Server did not save Listen preferences ${values.keys}",
                )
            }
            return saved
        }

        /** The listen_voices change that picks this voice for a language, keeping the other languages' choices. */
        fun voiceChange(
            language: String,
            voiceId: String,
        ): Map<String, Any> {
            val voices = current().voices.toMutableMap().apply { put(language, voiceId) }
            return mapOf(ListenPrefKeys.VOICES to voices)
        }

        /** Called by SyncService.kt with the preferences from /reader/feeds. */
        suspend fun applyServerPreferences(preferences: JsonObject?) {
            if (preferences == null) return
            // The old device-only toggle goes up first, so the server's copy can't overwrite it below.
            migrateLegacyAskAiToggle()
            val values = ListenPreferenceParser.parse(preferences)
            val now = elapsedRealtime()
            val fresh = { key: String ->
                recentLocalChanges[key]?.let { now - it < LOCAL_CHANGE_PRIORITY_MS } != true
            }
            prefs.edit {
                values.booleans.filterKeys(fresh).forEach { (key, value) -> putBoolean(key, value) }
                values.doubles.filterKeys(fresh).forEach { (key, value) ->
                    putFloat(key, value.toFloat())
                }
                values.strings.filterKeys(fresh).forEach { (key, value) -> putString(key, value) }
            }
        }

        /**
         * Someone who hid Ask AI on this device before it synced keeps it hidden: that choice is sent up once even
         * when the server already has a value, since the web preferences dialog saves Ask AI as shown for almost
         * everyone. The legacy key stays until the server takes it, so a failed send tries again next sync.
         */
        private suspend fun migrateLegacyAskAiToggle() {
            if (!prefs.contains(PrefConstants.SHOW_ASK_AI)) return
            val legacy = prefs.getBoolean(PrefConstants.SHOW_ASK_AI, true)
            if (!legacy && !save(mapOf(StoryButton.ASK_AI.prefKey to false))) return
            prefs.edit { remove(PrefConstants.SHOW_ASK_AI) }
        }

        private fun writeLocal(values: Map<String, Any>) {
            prefs.edit {
                values.forEach { (key, value) ->
                    when (value) {
                        is Boolean -> putBoolean(key, value)
                        is Double ->
                            putFloat(
                                key,
                                ListenPreferenceParser.clamp(key, value).toFloat(),
                            )
                        is Float ->
                            putFloat(
                                key,
                                ListenPreferenceParser.clamp(key, value.toDouble()).toFloat(),
                            )
                        is Map<*, *> -> putString(key, ListenPreferenceParser.serverString(value))
                        is ListenDelivery -> putString(key, value.value)
                        else -> putString(key, value.toString())
                    }
                }
            }
        }

        private fun readSettings(): ListenSettings =
            ListenSettings(
                voices =
                    ListenPreferenceParser
                        .voicesValue(
                            prefs.getString(ListenPrefKeys.VOICES, null)?.let { JsonPrimitive(it) },
                        ).orEmpty(),
                delivery = ListenDelivery.fromValue(prefs.getString(ListenPrefKeys.DELIVERY, null)),
                stability = readDouble(ListenPrefKeys.STABILITY, ListenSettings.DEFAULT_STABILITY),
                similarity =
                    readDouble(
                        ListenPrefKeys.SIMILARITY,
                        ListenSettings.DEFAULT_SIMILARITY,
                    ),
                style = readDouble(ListenPrefKeys.STYLE, ListenSettings.DEFAULT_STYLE),
                speakerBoost = prefs.getBoolean(ListenPrefKeys.SPEAKER_BOOST, true),
                speed = ListenSpeed.clamp(readDouble(ListenPrefKeys.SPEED, ListenSettings.DEFAULT_SPEED)),
                autoContinue = prefs.getBoolean(ListenPrefKeys.AUTO_CONTINUE, true),
                highlight = prefs.getBoolean(ListenPrefKeys.HIGHLIGHT, true),
            )

        private fun readDouble(
            key: String,
            default: Double,
        ): Double =
            try {
                prefs.getFloat(key, default.toFloat()).toDouble()
            } catch (_: ClassCastException) {
                default
            }

        companion object {
            private const val LOCAL_CHANGE_PRIORITY_MS = 120_000L
            private const val SPEED_SAVE_DEBOUNCE_MS = 400L
        }
    }
