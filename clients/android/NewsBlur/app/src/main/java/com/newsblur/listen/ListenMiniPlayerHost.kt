package com.newsblur.listen

import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.dp
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.newsblur.R
import com.newsblur.design.ListenPalette
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.UIUtils

/**
 * ListenMiniPlayerHost.kt adds ListenMiniPlayer.kt to a screen without touching its layout: the bar floats at
 * the bottom of the window and follows the screen's bottom toolbar (its anchor), sitting just above it.
 */
class ListenMiniPlayerHost(
    private val activity: FragmentActivity,
    private val listenManager: ListenManager,
    private val prefsRepo: PrefsRepo,
    private val anchor: () -> View?,
    private val onInsetChanged: (Int) -> Unit,
) {
    private val showsInThisPane = mutableStateOf(true)
    private var composeView: ComposeView? = null
    private var lastTranslation = Float.NaN
    private var lastInset = -1

    private val preDrawListener =
        ViewTreeObserver.OnPreDrawListener {
            reposition()
            true
        }

    fun attach() {
        if (composeView != null) return
        val content = activity.findViewById<FrameLayout>(android.R.id.content) ?: return
        val theme = prefsRepo.getResolvedTheme(activity)
        val colors = ListenPalette.colors(theme)
        val view =
            ComposeView(activity).apply {
                id = R.id.listen_mini_player
                // Screens give their bottom toolbars elevation; the mini player has to draw above them.
                elevation = UIUtils.dp2px(activity, 24).toFloat()
                setViewCompositionStrategy(
                    ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed,
                )
                setContent {
                    val state by listenManager.state.collectAsStateWithLifecycle()
                    val icon by listenManager.icon.collectAsStateWithLifecycle()
                    val showsHere by showsInThisPane
                    // The bottom padding leaves room for the bar's shadow inside this view's bounds.
                    Box(
                        modifier = Modifier.fillMaxWidth().padding(top = 4.dp, bottom = SHADOW_ROOM_DP.dp),
                        contentAlignment = Alignment.BottomCenter,
                    ) {
                        AnimatedVisibility(
                            visible = state.isActive && showsHere,
                            enter = slideInVertically { it / 2 } + fadeIn(),
                            exit = slideOutVertically { it / 2 } + fadeOut(),
                        ) {
                            ListenMiniPlayer(
                                state = state,
                                icon = icon,
                                colors = colors,
                                onOpen = {
                                    ListenNowPlayingFragment.show(activity.supportFragmentManager)
                                },
                                onPlayPause = listenManager::togglePlayPause,
                                onClose = listenManager::close,
                                modifier =
                                    Modifier
                                        .widthIn(max = 560.dp)
                                        .padding(horizontal = 12.dp),
                            )
                        }
                    }
                }
            }
        content.addView(
            view,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )
        composeView = view
        content.viewTreeObserver.addOnPreDrawListener(preDrawListener)
        view.addOnAttachStateChangeListener(
            object : View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(v: View) = Unit

                override fun onViewDetachedFromWindow(v: View) {
                    content.viewTreeObserver.removeOnPreDrawListener(preDrawListener)
                }
            },
        )
    }

    private companion object {
        const val SHADOW_ROOM_DP = 12
    }

    /** Hides the bar in a tablet pane when a neighboring pane shows it instead. */
    fun setShownInThisPane(shown: Boolean) {
        showsInThisPane.value = shown
    }

    private fun reposition() {
        val view = composeView ?: return
        val content = view.parent as? View ?: return
        val gap = UIUtils.dp2px(activity, 8)
        val shadowRoom = UIUtils.dp2px(activity, SHADOW_ROOM_DP)
        val anchorView = anchor()
        val offset =
            if (anchorView != null && anchorView.isShown && anchorView.height > 0) {
                val contentLocation = IntArray(2)
                val anchorLocation = IntArray(2)
                content.getLocationInWindow(contentLocation)
                anchorView.getLocationInWindow(anchorLocation)
                val anchorTop = anchorLocation[1] - contentLocation[1]
                (content.height - anchorTop + gap - shadowRoom).coerceAtLeast(0)
            } else {
                val navigationBar =
                    ViewCompat
                        .getRootWindowInsets(content)
                        ?.getInsets(WindowInsetsCompat.Type.navigationBars())
                        ?.bottom ?: 0
                (navigationBar + gap - shadowRoom).coerceAtLeast(0)
            }
        val translation = -offset.toFloat()
        if (translation != lastTranslation) {
            lastTranslation = translation
            view.translationY = translation
        }
        // The space the bar covers above the anchor, for screens that pad their lists to keep rows visible.
        val inset =
            if (view.height > 0 &&
                listenManager.state.value.isActive &&
                showsInThisPane.value
            ) {
                view.height - shadowRoom + gap
            } else {
                0
            }
        if (inset != lastInset) {
            lastInset = inset
            onInsetChanged(inset)
        }
    }
}
