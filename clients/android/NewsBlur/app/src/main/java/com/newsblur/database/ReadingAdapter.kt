package com.newsblur.database

import android.database.Cursor
import android.os.Bundle
import android.os.Parcelable
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.FragmentTransaction
import androidx.lifecycle.LifecycleCoroutineScope
import androidx.viewpager.widget.PagerAdapter
import androidx.viewpager.widget.ViewPager
import com.newsblur.activity.Reading
import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import com.newsblur.fragment.LoadingFragment
import com.newsblur.fragment.ReadingItemFragment
import com.newsblur.fragment.ReadingItemFragment.Companion.newInstance
import com.newsblur.service.NbSyncManager
import com.newsblur.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * An adapter to display stories in a ViewPager. Loosely based upon FragmentStatePagerAdapter, but
 * with enhancements to correctly handle item insertion / removal and to pass invalidation down
 * to child fragments during updates.
 */
class ReadingAdapter(
    private val fm: FragmentManager,
    private val sourceUserId: String?,
    private val showFeedMetadata: Boolean,
    private val activity: Reading,
    private val dbHelper: BlurDatabaseHelper,
) : PagerAdapter() {
    private val maxSavedStates = 3
    private val states =
        object : LinkedHashMap<String, Fragment.SavedState?>(16, 0.75f, true) {
            override fun removeEldestEntry(eldest: Map.Entry<String, Fragment.SavedState?>): Boolean = size > maxSavedStates
        }

    // the cursor from which we pull story objects. should not be used except by the thaw coro
    private var mostRecentCursor: Cursor? = null
    private var curTransaction: FragmentTransaction? = null
    private var lastActiveFragment: Fragment? = null

    private val fragments = mutableMapOf<String, ReadingItemFragment>()

    // the live list of stories being used by the adapter
    private val stories = mutableListOf<Story>()

    // classifiers for each feed seen in the story list
    private val classifiers = mutableMapOf<String, Classifier>()

    fun swapCursor(
        lifecycleScope: LifecycleCoroutineScope,
        cursor: Cursor,
    ) {
        // cache the identity of the most recent cursor so async batches can check to
        // see if they are stale
        mostRecentCursor = cursor
        // process the cursor into objects and update the View async
        lifecycleScope.launch(Dispatchers.IO) {
            thaw(cursor)
        }
    }

    /**
     * Attempt to thaw a new set of stories from the cursor most recently
     * seen when the that cycle started.
     */
    private suspend fun thaw(c: Cursor?) =
        coroutineScope {
            if (c !== mostRecentCursor) return@coroutineScope

            // thawed stories
            val newStories: MutableList<Story>
            // attempt to thaw as gracefully as possible despite the fact that the loader
            // framework could close our cursor at any moment.  if this happens, it is fine,
            // as a new one will be provided and another cycle will start.  just return.
            try {
                if (c == null) {
                    newStories = ArrayList(0)
                } else {
                    if (c.isClosed) return@coroutineScope
                    newStories = ArrayList(c.count)
                    // keep track of which feeds are in this story set so we can also fetch Classifiers
                    val feedIdsSeen: MutableSet<String> = HashSet()
                    c.moveToPosition(-1)
                    while (c.moveToNext()) {
                        if (c.isClosed) return@coroutineScope
                        val s = Story.fromCursor(c)
                        s.bindExternValues(c)
                        newStories.add(s)
                        feedIdsSeen.add(s.feedId)
                    }
                    for (feedId in feedIdsSeen) {
                        classifiers[feedId] = dbHelper.getClassifierForFeed(feedId)
                    }
                }
            } catch (e: Exception) {
                // because we use interruptable loaders that auto-close cursors, it is expected
                // that cursors will sometimes go bad. this is a useful signal to stop the thaw
                // thread and let it start on a fresh cursor.
                Log.e(this, "error thawing story list: " + e.message, e)
                return@coroutineScope
            }
            if (c !== mostRecentCursor) return@coroutineScope
            withContext(Dispatchers.Main) {
                stories.clear()
                stories.addAll(newStories)

                val valid = stories.map { it.storyHash }
                states.keys.retainAll(valid)

                notifyDataSetChanged()
                activity.pagerUpdated()
            }
        }

    fun getStory(position: Int): Story? =
        if (position >= stories.size || position < 0) {
            null
        } else {
            stories[position]
        }

    override fun getCount(): Int = stories.size

    private fun createFragment(story: Story): ReadingItemFragment =
        newInstance(
            story,
            story.extern_feedTitle,
            story.extern_feedColor,
            story.extern_feedFade,
            story.extern_faviconBorderColor,
            story.extern_faviconTextColor,
            story.extern_faviconUrl,
            classifiers[story.feedId],
            showFeedMetadata,
            sourceUserId,
        )

    override fun instantiateItem(
        container: ViewGroup,
        position: Int,
    ): Fragment {
        val story = getStory(position)
        val tag = story?.let { "reading:${it.storyHash}" } ?: "reading:loading:$position"

        var fragment = fm.findFragmentByTag(tag)
        if (fragment == null) {
            fragment = if (story == null) LoadingFragment() else createFragment(story)
            if (curTransaction == null) curTransaction = fm.beginTransaction()
            curTransaction?.add(container.id, fragment, tag)
        } else {
            if (curTransaction == null) curTransaction = fm.beginTransaction()
            curTransaction?.attach(fragment)
        }

        fragment.setMenuVisibility(false)
        if (fragment is ReadingItemFragment && story != null) {
            fragments[story.storyHash] = fragment
        }
        return fragment
    }

    override fun destroyItem(
        container: ViewGroup,
        position: Int,
        obj: Any,
    ) {
        val fragment = obj as Fragment
        if (curTransaction == null) {
            curTransaction = fm.beginTransaction()
        }
        curTransaction!!.detach(fragment)

        if (fragment is ReadingItemFragment) {
            fragment.story?.let { story ->
                if (fragment.isAdded && isNearCurrent(container, story.storyHash)) {
                    states[story.storyHash] = fm.saveFragmentInstanceState(fragment)
                } else {
                    states.remove(story.storyHash)
                }
                fragments.remove(story.storyHash)
            }
        }
    }

    override fun setPrimaryItem(
        container: ViewGroup,
        position: Int,
        obj: Any,
    ) {
        val fragment = obj as Fragment
        if (fragment !== lastActiveFragment) {
            lastActiveFragment?.setMenuVisibility(false)
            fragment.setMenuVisibility(true)
            lastActiveFragment = fragment
        }

        val keep: Set<String> =
            buildSet {
                for (p in (position - 1)..(position + 1)) {
                    getStory(p)?.storyHash?.let { add(it) }
                }
            }
        states.keys.retainAll(keep) // drop anything not near current
    }

    override fun finishUpdate(container: ViewGroup) {
        curTransaction?.commitNowAllowingStateLoss()
        curTransaction = null
    }

    override fun isViewFromObject(
        view: View,
        `object`: Any,
    ): Boolean = (`object` as Fragment).view === view

    /**
     * get the number of stories we very likely have, even if they haven't
     * been thawed yet, for callers that absolutely must know the size
     * of our dataset (such as for calculating when to fetch more stories)
     */
    val rawStoryCount: Int
        get() =
            mostRecentCursor?.let {
                if (it.isClosed) 0 else it.count
            } ?: 0

    fun getPosition(story: Story): Int {
        var pos = 0
        while (pos < stories.size) {
            if (stories[pos] == story) {
                return pos
            }
            pos++
        }
        return -1
    }

    override fun getItemPosition(`object`: Any): Int {
        if (`object` is ReadingItemFragment) {
            val pos = findHash(`object`.story!!.storyHash)
            if (pos >= 0) return pos
        }
        return POSITION_NONE
    }

    fun getExistingItem(pos: Int): ReadingItemFragment? = getStory(pos)?.let { fragments[it.storyHash] }

    override fun notifyDataSetChanged() {
        super.notifyDataSetChanged()

        // go one step further than the default pager adapter and also refresh the
        // story object inside each fragment we have active
        for (s in stories) {
            fragments[s.storyHash]?.let { rif ->
                rif.offerStoryUpdate(s)
                rif.handleUpdate(NbSyncManager.UPDATE_STORY)
            }
        }
    }

    fun findFirstUnread(): Int {
        var pos = 0
        while (pos < stories.size) {
            if (!stories[pos].read) {
                return pos
            }
            pos++
        }
        return -1
    }

    fun findHash(storyHash: String): Int {
        var pos = 0
        while (pos < stories.size) {
            if (stories[pos].storyHash == storyHash) {
                return pos
            }
            pos++
        }
        return -1
    }

    override fun saveState(): Parcelable {
        if (states.isEmpty()) return Bundle.EMPTY
        return Bundle().apply {
            for ((key, value) in states) putParcelable("ss-$key", value)
        }
    }

    override fun restoreState(
        state: Parcelable?,
        loader: ClassLoader?,
    ) {
        val bundle = state as? Bundle ?: return
        bundle.classLoader = loader
        fragments.clear()
        states.clear()
        for (key in bundle.keySet()) {
            if (key.startsWith("ss-")) {
                val storyHash = key.removePrefix("ss-")
                states[storyHash] = bundle.getParcelable(key)
            }
        }
    }

    private fun isNearCurrent(
        container: ViewGroup,
        storyHash: String,
    ): Boolean {
        val vp = container as? ViewPager ?: return false
        val cur = vp.currentItem
        val pos = findHash(storyHash)
        return pos in (cur - 1..cur + 1)
    }
}
