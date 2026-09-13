package com.newsblur.view

import android.view.MotionEvent
import android.view.View
import android.widget.ExpandableListView
import androidx.appcompat.app.AlertDialog
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.database.FolderListAdapter
import com.newsblur.domain.Feed
import com.newsblur.fragment.FeedIntelTrainerFragment
import com.newsblur.fragment.ReadingActionConfirmationFragment
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FeedExt.isAndroidNotifyFocus
import com.newsblur.util.FeedExt.isAndroidNotifyUnread
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.GestureAction
import com.newsblur.util.GestureLabels
import com.newsblur.util.GestureSwipeAction
import com.newsblur.util.ReadingAction

/** FeedListGestures.kt captures feed identity before a drag, independent of later list refreshes. */
class FeedListGestures(
    private val list: ExpandableListView,
    private val adapter: FolderListAdapter,
    private val prefs: PrefsRepo,
    private val feedUtils: FeedUtils,
    private val activity: NbActivity,
) : View.OnTouchListener {
    private var swipe: RowSwipeGesture? = null
    private var targetRow: View? = null
    private var targetPosition = -1
    private var target: Target? = null

    private data class Target(
        val fs: FeedSet,
        val title: String,
        val feed: Feed?,
    )

    init {
        list.setOnTouchListener(this)
        list.setOnItemLongClickListener { _, _, position, _ ->
            val selected = targetAt(position) ?: return@setOnItemLongClickListener false
            val action = prefs.getFeedLongPressAction()
            if (action == GestureAction.GEST_ACTION_MENU) return@setOnItemLongClickListener false
            swipe?.cancel()
            perform(selected, action)
            true
        }
    }

    private fun targetAt(position: Int): Target? {
        val packed = list.getExpandableListPosition(position)
        val group = ExpandableListView.getPackedPositionGroup(packed)
        if (group !in 0 until adapter.groupCount) return null
        if (ExpandableListView.getPackedPositionType(packed) == ExpandableListView.PACKED_POSITION_TYPE_CHILD) {
            val child = ExpandableListView.getPackedPositionChild(packed)
            val feed = adapter.getGestureFeed(group, child) ?: return null
            return Target(FeedSet.singleFeed(feed.feedId), feed.title, feed)
        }
        val folder = adapter.getGroupFolder(group)
        if (folder != null || adapter.isRowAllStories(group)) {
            return Target(adapter.getGroup(group), folder?.name ?: activity.getString(R.string.all_stories), null)
        }
        return null
    }

    override fun onTouch(
        view: View,
        event: MotionEvent,
    ): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            swipe?.cancel()
            targetPosition = list.pointToPosition(event.x.toInt(), event.y.toInt())
            target = targetAt(targetPosition)
            targetRow = list.getChildAt(targetPosition - list.firstVisiblePosition)
            val selected = target
            val row = targetRow
            swipe =
                if (selected == null || row == null) {
                    null
                } else {
                    RowSwipeGesture(
                        row,
                        action = { right ->
                            val action = prefs.getFeedSwipeAction(right)
                            if (!prefs.isFeedSwipesEnabled() ||
                                action == GestureAction.GEST_ACTION_NONE ||
                                (selected.feed == null && action != GestureAction.GEST_ACTION_MARKREAD)
                            ) {
                                null
                            } else {
                                GestureSwipeAction.resolve(action)?.let {
                                    if (action == GestureAction.GEST_ACTION_MARKREAD) it.copy(iconRes = R.drawable.ic_mark_read) else it
                                }
                            }
                        },
                        perform = { perform(selected, it.action) },
                        actionDescription = {
                            if (it.action == GestureAction.GEST_ACTION_MARKREAD) {
                                activity.getString(R.string.gesture_mark_all)
                            } else {
                                GestureLabels.title(activity, it.action)
                            }
                        },
                        colors = {
                            com.newsblur.util.GestureThemeStyle
                                .palette(prefs.getResolvedTheme(activity))
                        },
                        claim = {
                            // FeedListGestures.kt cancels AbsListView's pending click/long press when horizontal dragging wins.
                            val cancel =
                                MotionEvent.obtain(
                                    android.os.SystemClock.uptimeMillis(),
                                    android.os.SystemClock.uptimeMillis(),
                                    MotionEvent.ACTION_CANCEL,
                                    0f,
                                    0f,
                                    0,
                                )
                            cancel.action = MotionEvent.ACTION_CANCEL
                            list.onTouchEvent(cancel)
                            cancel.recycle()
                        },
                    )
                }
        } else if (targetRow !== list.getChildAt(targetPosition - list.firstVisiblePosition) ||
            targetAt(targetPosition)?.fs != target?.fs
        ) {
            swipe?.cancel()
            return false
        }
        return swipe?.onTouch(event) ?: false
    }

    private fun perform(
        target: Target,
        action: GestureAction,
    ) {
        when (action) {
            GestureAction.GEST_ACTION_MARKREAD -> feedUtils.markRead(activity, target.fs, null, null, R.array.mark_all_read_options)
            GestureAction.GEST_ACTION_READ_RANGE ->
                ReadingActionConfirmationFragment
                    .newInstance(
                        ReadingAction.MarkFeedRead(target.fs, null, null),
                        target.title,
                        null,
                        R.array.mark_all_read_options,
                        null,
                    ).show(activity.supportFragmentManager, "dialog")
            GestureAction.GEST_ACTION_STATISTICS -> target.feed?.let { feedUtils.openStatistics(activity, prefs, it.feedId) }
            GestureAction.GEST_ACTION_TRAIN ->
                target.feed?.let {
                    FeedIntelTrainerFragment.newInstance(it, target.fs).show(activity.supportFragmentManager, "feed-gesture-trainer")
                }
            GestureAction.GEST_ACTION_NOTIFICATIONS ->
                target.feed?.let { feed ->
                    AlertDialog
                        .Builder(activity)
                        .setTitle(activity.getString(R.string.gesture_notifications))
                        .setSingleChoiceItems(
                            arrayOf(
                                activity.getString(R.string.gesture_off),
                                activity.getString(R.string.gesture_unread_stories),
                                activity.getString(R.string.gesture_focus_stories),
                            ),
                            when {
                                feed.isAndroidNotifyUnread() -> 1
                                feed.isAndroidNotifyFocus() -> 2
                                else -> 0
                            },
                        ) { dialog, index ->
                            when (index) {
                                1 -> feedUtils.enableUnreadNotifications(activity, feed)
                                2 -> feedUtils.enableFocusNotifications(activity, feed)
                                else -> feedUtils.disableNotifications(activity, feed)
                            }
                            dialog.dismiss()
                        }.setNegativeButton(android.R.string.cancel, null)
                        .show()
                }
            else -> Unit
        }
    }
}
