package com.newsblur.listen

import android.net.Uri
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import androidx.media3.exoplayer.ExoPlayer
import com.newsblur.preference.ListenPreferences
import com.newsblur.preference.ListenSettings
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.Test

/** Test_ListenVoicePreviewFocus.kt exercises the real preview path with a podcast loaded in ListenManager.kt. */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class Test_ListenVoicePreviewFocus {
    @Test
    fun test_a_paused_podcast_does_not_make_voice_previews_pause_other_music() {
        Dispatchers.setMain(StandardTestDispatcher())
        mockkStatic(Uri::class)
        every { Uri.parse(any()) } returns mockk(relaxed = true)
        try {
            val preferences = mockk<ListenPreferences>(relaxed = true)
            every { preferences.current() } returns ListenSettings()
            val mix = mockk<ListenAudioMix>()
            every { mix.current() } returns ListenAudioMixSettings(playsOverOtherAudio = true)
            val manager = ListenManager(mockk(relaxed = true), mockk(), preferences, mockk(), mockk(), mockk(), mockk(), mix)
            ListenManager::class.java.getDeclaredField("story").apply { isAccessible = true }.set(
                manager,
                ListenStory("1:podcast", "Episode", "1", "Feed", null, null, null, null, ListenMedia("https://example.com/podcast.mp3")),
            )
            val model = ListenVoiceSettingsViewModel(mockk(), mockk(), preferences, manager)
            val preview = mockk<ExoPlayer>(relaxed = true)
            ListenVoiceSettingsViewModel::class.java.getDeclaredField("previewPlayer").apply { isAccessible = true }.set(model, preview)
            ListenVoiceSettingsViewModel::class.java.getDeclaredMethod("playPreview", String::class.java, String::class.java)
                .apply { isAccessible = true }.invoke(model, "voice", "https://example.com/voice.mp3")
            verify { preview.setAudioAttributes(ListenSessionPlayer.AUDIO_ATTRIBUTES, false) }
        } finally {
            unmockkStatic(Uri::class)
            Dispatchers.resetMain()
        }
    }
}
