package com.newsblur.listen

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import androidx.annotation.OptIn
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.CommandButton
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionError
import androidx.media3.session.SessionResult
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.newsblur.R
import com.newsblur.util.PendingIntentUtils
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ListenPlaybackService.kt keeps Listen and podcast episodes playing with the screen off or the app in the
 * background. Media3 runs it in the foreground while audio plays and builds the media notification and lock screen
 * controls from ListenSessionPlayer.kt: skip back, play or pause, skip forward, and the next story, with the skip
 * intervals set in the web media player (15 and 30 seconds unless changed there).
 */
@OptIn(UnstableApi::class)
@AndroidEntryPoint
class ListenPlaybackService : MediaSessionService() {
    @Inject
    lateinit var listenManager: ListenManager

    private var session: MediaSession? = null
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onCreate() {
        super.onCreate()
        setMediaNotificationProvider(
            DefaultMediaNotificationProvider
                .Builder(this)
                .setChannelId(CHANNEL_ID)
                .setChannelName(R.string.listen_notification_channel_name)
                .build()
                .apply { setSmallIcon(R.drawable.ic_listen_notification) },
        )
        val initial = listenManager.state.value
        session =
            MediaSession
                .Builder(this, listenManager.sessionPlayer)
                .setId(SESSION_ID)
                .apply { openAppIntent()?.let(::setSessionActivity) }
                .setCallback(SessionCallback())
                .setMediaButtonPreferences(mediaButtons(initial.skipBackSeconds, initial.skipForwardSeconds))
                .build()
        serviceScope.launch {
            // The skip intervals arrive with the playback state, and can change on the web while this runs.
            listenManager.state
                .map { it.skipBackSeconds to it.skipForwardSeconds }
                .distinctUntilChanged()
                .collect { (back, forward) -> session?.setMediaButtonPreferences(mediaButtons(back, forward)) }
        }
    }

    /**
     * ListenPlaybackService.kt sends the skips as custom commands: Android's media controls show custom actions in
     * the back and forward slots, but never show plain rewind and fast forward. The icons show the interval when
     * Media3 has one for it, and a plain skip arrow otherwise.
     */
    private fun mediaButtons(
        backSeconds: Int,
        forwardSeconds: Int,
    ): List<CommandButton> {
        val skipBack =
            CommandButton
                .Builder(skipBackIcon(backSeconds))
                .setSessionCommand(SKIP_BACK_COMMAND)
                .setDisplayName(resources.getQuantityString(R.plurals.listen_skip_back_seconds, backSeconds, backSeconds))
                .setSlots(CommandButton.SLOT_BACK)
                .build()
        val skipForward =
            CommandButton
                .Builder(skipForwardIcon(forwardSeconds))
                .setSessionCommand(SKIP_FORWARD_COMMAND)
                .setDisplayName(resources.getQuantityString(R.plurals.listen_skip_forward_seconds, forwardSeconds, forwardSeconds))
                .setSlots(CommandButton.SLOT_FORWARD)
                .build()
        val nextStory =
            CommandButton
                .Builder(CommandButton.ICON_NEXT)
                .setPlayerCommand(Player.COMMAND_SEEK_TO_NEXT)
                .setDisplayName(getString(R.string.listen_next_story))
                .setSlots(CommandButton.SLOT_OVERFLOW)
                .build()
        return listOf(skipBack, skipForward, nextStory)
    }

    private fun skipBackIcon(seconds: Int): Int =
        when (seconds) {
            5 -> CommandButton.ICON_SKIP_BACK_5
            10 -> CommandButton.ICON_SKIP_BACK_10
            15 -> CommandButton.ICON_SKIP_BACK_15
            30 -> CommandButton.ICON_SKIP_BACK_30
            else -> CommandButton.ICON_SKIP_BACK
        }

    private fun skipForwardIcon(seconds: Int): Int =
        when (seconds) {
            5 -> CommandButton.ICON_SKIP_FORWARD_5
            10 -> CommandButton.ICON_SKIP_FORWARD_10
            15 -> CommandButton.ICON_SKIP_FORWARD_15
            30 -> CommandButton.ICON_SKIP_FORWARD_30
            else -> CommandButton.ICON_SKIP_FORWARD
        }

    private inner class SessionCallback : MediaSession.Callback {
        override fun onConnect(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
        ): MediaSession.ConnectionResult =
            MediaSession.ConnectionResult
                .AcceptedResultBuilder(session)
                .setAvailableSessionCommands(
                    MediaSession.ConnectionResult.DEFAULT_SESSION_COMMANDS
                        .buildUpon()
                        .add(SKIP_BACK_COMMAND)
                        .add(SKIP_FORWARD_COMMAND)
                        .build(),
                ).build()

        override fun onCustomCommand(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            customCommand: SessionCommand,
            args: Bundle,
        ): ListenableFuture<SessionResult> {
            when (customCommand.customAction) {
                SKIP_BACK_COMMAND.customAction -> listenManager.skipBack()
                SKIP_FORWARD_COMMAND.customAction -> listenManager.skipForward()
                else -> return Futures.immediateFuture(SessionResult(SessionError.ERROR_NOT_SUPPORTED))
            }
            return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    override fun onTaskRemoved(rootIntent: Intent?) {
        listenManager.flushProgress()
        // Swiping the app away keeps a playing story going, but a paused one has nothing left to do.
        if (!isPlaybackOngoing) pauseAllPlayersAndStopSelf()
    }

    override fun onDestroy() {
        serviceScope.cancel()
        listenManager.flushProgress()
        session?.release()
        session = null
        super.onDestroy()
    }

    private fun openAppIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        return PendingIntentUtils.getImmutableActivity(
            this,
            REQUEST_OPEN_APP,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    companion object {
        private const val CHANNEL_ID = "listen_playback"
        private const val SESSION_ID = "newsblur_listen"
        private const val REQUEST_OPEN_APP = 7_301
        private val SKIP_BACK_COMMAND = SessionCommand("com.newsblur.listen.SKIP_BACK", Bundle.EMPTY)
        private val SKIP_FORWARD_COMMAND = SessionCommand("com.newsblur.listen.SKIP_FORWARD", Bundle.EMPTY)
    }
}
