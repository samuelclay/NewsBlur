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
import javax.inject.Inject

/**
 * ListenPlaybackService.kt keeps Listen playing with the screen off or the app in the background. Media3 runs
 * it in the foreground while audio plays and builds the media notification and lock screen controls from
 * ListenSessionPlayer.kt: skip back 15 seconds, play or pause, skip forward 30 seconds, and the next story.
 */
@OptIn(UnstableApi::class)
@AndroidEntryPoint
class ListenPlaybackService : MediaSessionService() {
    @Inject
    lateinit var listenManager: ListenManager

    private var session: MediaSession? = null

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
        // ListenPlaybackService.kt sends the skips as custom commands: Android's media controls show custom
        // actions in the back and forward slots, but never show plain rewind and fast forward.
        val skipBack =
            CommandButton
                .Builder(CommandButton.ICON_SKIP_BACK_15)
                .setSessionCommand(SKIP_BACK_COMMAND)
                .setDisplayName(getString(R.string.listen_skip_back))
                .setSlots(CommandButton.SLOT_BACK)
                .build()
        val skipForward =
            CommandButton
                .Builder(CommandButton.ICON_SKIP_FORWARD_30)
                .setSessionCommand(SKIP_FORWARD_COMMAND)
                .setDisplayName(getString(R.string.listen_skip_forward))
                .setSlots(CommandButton.SLOT_FORWARD)
                .build()
        val nextStory =
            CommandButton
                .Builder(CommandButton.ICON_NEXT)
                .setPlayerCommand(Player.COMMAND_SEEK_TO_NEXT)
                .setDisplayName(getString(R.string.listen_next_story))
                .setSlots(CommandButton.SLOT_OVERFLOW)
                .build()
        session =
            MediaSession
                .Builder(this, listenManager.sessionPlayer)
                .setId(SESSION_ID)
                .apply { openAppIntent()?.let(::setSessionActivity) }
                .setCallback(SessionCallback())
                .setMediaButtonPreferences(listOf(skipBack, skipForward, nextStory))
                .build()
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
