package com.newsblur.preference

import com.google.gson.JsonParser
import com.google.gson.JsonPrimitive
import com.newsblur.util.StoryButton
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Test_ListenPreferenceParser.kt checks the lenient reading of synced Listen and story button prefs. */
class Test_ListenPreferenceParser {
    private fun json(raw: String) = JsonParser.parseString(raw).asJsonObject

    @Test
    fun test_booleans_accept_strings_and_numbers() {
        assertEquals(true, ListenPreferenceParser.booleanValue(JsonPrimitive(true)))
        assertEquals(false, ListenPreferenceParser.booleanValue(JsonPrimitive("false")))
        assertEquals(true, ListenPreferenceParser.booleanValue(JsonPrimitive("True")))
        assertEquals(false, ListenPreferenceParser.booleanValue(JsonPrimitive(0)))
        assertEquals(true, ListenPreferenceParser.booleanValue(JsonPrimitive("1")))
        assertNull(ListenPreferenceParser.booleanValue(JsonPrimitive("maybe")))
        assertNull(ListenPreferenceParser.booleanValue(null))
    }

    @Test
    fun test_numbers_accept_strings() {
        assertEquals(1.25, ListenPreferenceParser.doubleValue(JsonPrimitive("1.25"))!!, 0.0)
        assertEquals(0.3, ListenPreferenceParser.doubleValue(JsonPrimitive(0.3))!!, 0.0)
        assertNull(ListenPreferenceParser.doubleValue(JsonPrimitive("fast")))
        assertNull(ListenPreferenceParser.doubleValue(JsonPrimitive("NaN")))
    }

    @Test
    fun test_voices_accept_encoded_string_or_object() {
        val encoded = JsonPrimitive("{\"en\": \"abc\", \"fr\": \"def\", \"de\": \"\"}")
        assertEquals(
            mapOf("en" to "abc", "fr" to "def"),
            ListenPreferenceParser.voicesValue(encoded),
        )
        assertEquals(
            mapOf("he" to "xyz"),
            ListenPreferenceParser.voicesValue(json("{\"he\": \"xyz\"}")),
        )
        assertNull(ListenPreferenceParser.voicesValue(JsonPrimitive("not json")))
    }

    @Test
    fun test_voices_encode_as_a_json_string() {
        val encoded = ListenPreferenceParser.encodeVoices(mapOf("fr" to "def", "en" to "abc"))
        assertEquals("{\"en\":\"abc\",\"fr\":\"def\"}", encoded)
        assertEquals(
            mapOf("en" to "abc", "fr" to "def"),
            ListenPreferenceParser.voicesValue(JsonPrimitive(encoded)),
        )
    }

    @Test
    fun test_parse_reads_only_listen_and_story_button_keys() {
        val values =
            ListenPreferenceParser.parse(
                json(
                    """
                    {"listen_speed": "1.5", "listen_stability": 0.8, "listen_auto_continue": "false",
                     "listen_highlight": true, "listen_delivery": "expressive",
                     "listen_voices": "{\"en\": \"abc\"}", "show_sideoption_listen": false,
                     "show_sideoption_ask_ai": "true", "timezone": "America/New_York"}
                    """.trimIndent(),
                ),
            )
        assertEquals(1.5, values.doubles[ListenPrefKeys.SPEED]!!, 0.0)
        assertEquals(0.8, values.doubles[ListenPrefKeys.STABILITY]!!, 0.0)
        assertEquals(false, values.booleans[ListenPrefKeys.AUTO_CONTINUE])
        assertEquals(true, values.booleans[ListenPrefKeys.HIGHLIGHT])
        assertEquals(false, values.booleans[StoryButton.LISTEN.prefKey])
        assertEquals(true, values.booleans[StoryButton.ASK_AI.prefKey])
        assertEquals("expressive", values.strings[ListenPrefKeys.DELIVERY])
        assertEquals("{\"en\":\"abc\"}", values.strings[ListenPrefKeys.VOICES])
        assertFalse("timezone" in values.keys)
    }

    @Test
    fun test_parse_clamps_out_of_range_values() {
        val values =
            ListenPreferenceParser.parse(
                json("{\"listen_speed\": 9, \"listen_style\": -1, \"listen_delivery\": \"loud\"}"),
            )
        assertEquals(ListenSettings.MAX_SPEED, values.doubles[ListenPrefKeys.SPEED]!!, 0.0)
        assertEquals(0.0, values.doubles[ListenPrefKeys.STYLE]!!, 0.0)
        assertEquals(ListenDelivery.NATURAL.value, values.strings[ListenPrefKeys.DELIVERY])
    }

    @Test
    fun test_parse_of_missing_preferences_is_empty() {
        assertTrue(ListenPreferenceParser.parse(null).keys.isEmpty())
        assertTrue(ListenPreferenceParser.parse(json("{}")).keys.isEmpty())
    }

    @Test
    fun test_server_strings_match_set_preference() {
        assertEquals("true", ListenPreferenceParser.serverString(true))
        assertEquals("1.25", ListenPreferenceParser.serverString(1.25))
        assertEquals("1", ListenPreferenceParser.serverString(1.0))
        assertEquals("0.3", ListenPreferenceParser.serverString(0.30000001192092896))
        assertEquals("{\"en\":\"abc\"}", ListenPreferenceParser.serverString(mapOf("en" to "abc")))
        assertEquals("natural", ListenPreferenceParser.serverString("natural"))
    }

    @Test
    fun test_speed_saves_as_a_two_place_decimal_and_reads_leniently() {
        assertEquals("1.05", ListenPreferenceParser.serverString(ListenPrefKeys.SPEED, 1.05f.toDouble()))
        assertEquals("1.05", ListenPreferenceParser.serverString(ListenPrefKeys.SPEED, 1.05f))
        assertEquals("1.07", ListenPreferenceParser.serverString(ListenPrefKeys.SPEED, 1.0749))
        assertEquals("1", ListenPreferenceParser.serverString(ListenPrefKeys.SPEED, 1.0))
        assertEquals("0.333", ListenPreferenceParser.serverString(ListenPrefKeys.STABILITY, 0.3333))
        val values = ListenPreferenceParser.parse(json("{\"listen_speed\": \" 1.053 \"}"))
        assertEquals(1.05, values.doubles[ListenPrefKeys.SPEED]!!, 0.0)
    }

    @Test
    fun test_delivery_presets_match_the_server() {
        assertEquals(
            ListenVoiceSettings(0.75, 0.75, 0.0),
            ListenVoiceSettings.forPreset(ListenDelivery.STEADY),
        )
        assertEquals(
            ListenVoiceSettings(0.5, 0.75, 0.0),
            ListenVoiceSettings.forPreset(ListenDelivery.NATURAL),
        )
        assertEquals(
            ListenVoiceSettings(0.3, 0.75, 0.35),
            ListenVoiceSettings.forPreset(ListenDelivery.EXPRESSIVE),
        )
        assertNull(ListenVoiceSettings.forPreset(ListenDelivery.CUSTOM))
    }
}
