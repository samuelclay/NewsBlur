package com.newsblur.database

import android.database.Cursor
import android.os.Bundle
import android.os.Parcelable
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.FragmentTransaction
import androidx.viewpager.widget.PagerAdapter
import com.newsblur.activity.Reading
import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import com.newsblur.fragment.LoadingFragment
import com.newsblur.fragment.ReadingItemFragment
import com.newsblur.fragment.ReadingItemFragment.Companion.newInstance
import com.newsblur.service.NbSyncManager
import com.newsblur.util.Log
import com.newsblur.util.NBScope
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

    // the cursor from which we pull story objects. should not be used except by the thaw coro
    private var mostRecentCursor: Cursor? = null
    private var curTransaction: FragmentTransaction? = null
    private var lastActiveFragment: Fragment? = null

    private val fragments = mutableMapOf<String, ReadingItemFragment>()
    private val states = mutableMapOf<String, Fragment.SavedState?>()

    // the live list of stories being used by the adapter
    private val stories = mutableListOf<Story>()

    // classifiers for each feed seen in the story list
    private val classifiers = mutableMapOf<String, Classifier>()

    fun swapCursor(cursor: Cursor) {
        // cache the identity of the most recent cursor so async batches can check to
        // see if they are stale
        mostRecentCursor = cursor
        // process the cursor into objects and update the View async
        NBScope.launch(Dispatchers.IO) {
            thaw(cursor)
        }
    }

    /**
     * Attempt to thaw a new set of stories from the cursor most recently
     * seen when the that cycle started.
     */
    private suspend fun thaw(c: Cursor?) = coroutineScope {
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
            notifyDataSetChanged()
            activity.pagerUpdated()
        }
    }

    fun getStory(position: Int): Story? =
            if (position >= stories.size || position < 0) null
            else stories[position]

    override fun getCount(): Int = stories.size

    private fun createFragment(story: Story): ReadingItemFragment = newInstance(
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

    override fun instantiateItem(container: ViewGroup, position: Int): Fragment {
        val story = getStory(position)
        var fragment: Fragment?
        if (story == null) {
            fragment = LoadingFragment()
        } else {
            fragment = fragments[story.storyHash]
            if (fragment == null) {
                val rif = createFragment(story)
                fragment = rif
                val oldState = states[story.storyHash]
                if (oldState != null) fragment.setInitialSavedState(oldState)
                fragments[story.storyHash] = rif
            } else {
                // if there was a real fragment for this story already, it will have been added and ready
                return fragment
            }
        }
        fragment.setMenuVisibility(false)
        if (curTransaction == null) {
            curTransaction = fm.beginTransaction()
        }
        curTransaction!!.add(container.id, fragment)
        return fragment
    }

    override fun destroyItem(container: ViewGroup, position: Int, `object`: Any) {
        val fragment = `object` as Fragment
        if (curTransaction == null) {
            curTransaction = fm.beginTransaction()
        }
        curTransaction!!.remove(fragment)
        if (fragment is ReadingItemFragment) {
            fragment.story?.let { story ->
                if (fragment.isAdded) {
                    states[story.storyHash] = fm.saveFragmentInstanceState(fragment)
                }
                fragments.remove(story.storyHash)
            }
        }
    }

    override fun setPrimaryItem(container: ViewGroup, position: Int, `object`: Any) {
        val fragment = `object` as Fragment
        if (fragment !== lastActiveFragment) {
            lastActiveFragment?.setMenuVisibility(false)
            fragment.setMenuVisibility(true)
            lastActiveFragment = fragment
        }
    }

    override fun finishUpdate(container: ViewGroup) {
        curTransaction?.commitNowAllowingStateLoss()
        curTransaction = null
    }

    override fun isViewFromObject(view: View, `object`: Any): Boolean =
            (`object` as Fragment).view === view

    /**
     * get the number of stories we very likely have, even if they haven't
     * been thawed yet, for callers that absolutely must know the size
     * of our dataset (such as for calculating when to fetch more stories)
     */
    val rawStoryCount: Int
        get() = mostRecentCursor?.let {
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

    fun getExistingItem(pos: Int): ReadingItemFragment? =
            getStory(pos)?.let { fragments[it.storyHash] }

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
        // collect state from any active fragments alongside already-frozen ones
        for ((key, f) in fragments) {
            if (f.isAdded) {
                states[key] = fm.saveFragmentInstanceState(f)
            }
        }
        val state = Bundle()
        for ((key, value) in states) {
            state.putParcelable("ss-$key", value)
        }
        return state
    }

    override fun restoreState(state: Parcelable?, loader: ClassLoader?) {
        // most FragmentManager impls. will re-create added fragments even if they
        // are not set to retaininstance. we want to only save state, not objects,
        // so before we start restoration, clear out any stale instances.  without
        // this, the pager will leak fragments on rotation or context switch.
        for (fragment in fm.fragments) {
            if (fragment is ReadingItemFragment) {
                fm.beginTransaction().remove(fragment).commit()
            }
        }
        val bundle = state as Bundle
        bundle.classLoader = loader
        fragments.clear()
        states.clear()
        for (key in bundle.keySet()) {
            if (key.startsWith("ss-")) {
                val storyHash = key.substring(3)
                val fragState = bundle.getParcelable<Parcelable>(key)
                states[storyHash] = fragState as Fragment.SavedState?
            }
        }
    }
}