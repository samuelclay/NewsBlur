package com.newsblur.fragment

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.*
import android.widget.AdapterView.OnItemClickListener
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.activity.Profile
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.FragmentProfileactivityBinding
import com.newsblur.databinding.RowLoadingThrobberBinding
import com.newsblur.di.IconLoader
import com.newsblur.domain.ActivityDetails
import com.newsblur.domain.UserDetails
import com.newsblur.network.APIManager
import com.newsblur.util.*
import com.newsblur.view.ActivityDetailsAdapter
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
abstract class ProfileActivityDetailsFragment : Fragment(), OnItemClickListener {

    @Inject
    lateinit var apiManager: APIManager

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    private lateinit var binding: FragmentProfileactivityBinding
    private lateinit var footerBinding: RowLoadingThrobberBinding

    private var adapter: ActivityDetailsAdapter? = null
    private var user: UserDetails? = null

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        val view = inflater.inflate(R.layout.fragment_profileactivity, null)
        binding = FragmentProfileactivityBinding.bind(view)
        val colorsArray = intArrayOf(ContextCompat.getColor(requireContext(), R.color.refresh_1),
                ContextCompat.getColor(requireContext(), R.color.refresh_2),
                ContextCompat.getColor(requireContext(), R.color.refresh_3),
                ContextCompat.getColor(requireContext(), R.color.refresh_4))
        binding.emptyViewLoadingThrob.setColors(*colorsArray)
        binding.profileDetailsActivitylist.setFooterDividersEnabled(false)
        binding.profileDetailsActivitylist.emptyView = binding.emptyView

        val footerView = inflater.inflate(R.layout.row_loading_throbber, null)
        footerBinding = RowLoadingThrobberBinding.bind(footerView)
        footerBinding.itemlistLoadingThrob.setColors(*colorsArray)
        binding.profileDetailsActivitylist.addFooterView(footerView, null, false)
        if (adapter != null) {
            displayActivities()
        }
        binding.profileDetailsActivitylist.setOnScrollListener(EndlessScrollListener())
        binding.profileDetailsActivitylist.onItemClickListener = this
        return view
    }

    fun setUser(context: Context?, user: UserDetails?, iconLoader: ImageLoader) {
        this.user = user
        adapter = createAdapter(context, user, iconLoader)
        displayActivities()
    }

    protected abstract fun createAdapter(context: Context?, user: UserDetails?, iconLoader: ImageLoader): ActivityDetailsAdapter?
    private fun displayActivities() {
        binding.profileDetailsActivitylist.adapter = adapter
        loadPage(1)
    }

    private fun loadPage(pageNumber: Int) {
        lifecycleScope.executeAsyncTask(
                onPreExecute = {
                    binding.emptyViewLoadingThrob.visibility = View.VISIBLE
                    footerBinding.itemlistLoadingThrob.visibility = View.VISIBLE
                },
                doInBackground = {
                    // For the logged in user user.userId is null.
                    // From the user intent user.userId is the number while user.id is prefixed with social:
                    var id = user!!.userId
                    if (id == null) {
                        id = user!!.id
                    }
                    id?.let { loadActivityDetails(it, pageNumber) }
                },
                onPostExecute = {
                    if (it == null) {
                        Log.w(javaClass.name, "couldn't load page from API")
                        return@executeAsyncTask
                    }
                    if (pageNumber == 1 && it.isEmpty()) {
                        val emptyView = binding.profileDetailsActivitylist.emptyView
                        val textView = emptyView.findViewById<View>(R.id.empty_view_text) as TextView
                        textView.setText(R.string.profile_no_interactions)
                    }
                    for (activity in it) {
                        adapter!!.add(activity)
                    }
                    adapter!!.notifyDataSetChanged()
                    binding.emptyViewLoadingThrob.visibility = View.GONE
                    footerBinding.itemlistLoadingThrob.visibility = View.GONE
                }
        )
    }

    protected abstract fun loadActivityDetails(id: String?, pageNumber: Int): Array<ActivityDetails>?

    override fun onItemClick(adapterView: AdapterView<*>?, view: View, position: Int, id: Long) {
        val activity = adapter!!.getItem(position)
        val context: Context = requireContext()
        if (activity!!.category == ActivityDetails.Category.FOLLOW) {
            val i = Intent(context, Profile::class.java)
            i.putExtra(Profile.USER_ID, activity.withUserId)
            context.startActivity(i)
        } else if (activity.category == ActivityDetails.Category.FEED_SUBSCRIPTION) {
            val feed = dbHelper.getFeed(activity.feedId)
            if (feed == null) {
                Toast.makeText(context, R.string.profile_feed_not_available, Toast.LENGTH_SHORT).show()
            } else {
                /* TODO: starting the feed view activity also requires both a feedset and a folder name
                   in order to properly function.  the latter, in particular, we could only guess at from
                   the info we have here.  at best, we would launch a feed view with somewhat unpredictable
                   delete behaviour. */
                //Intent intent = new Intent(context, FeedItemsList.class);
                //intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
                //context.startActivity(intent);
            }
        } else if (activity.category == ActivityDetails.Category.STAR) {
            UIUtils.startReadingActivity(FeedSet.allSaved(), activity.storyHash, context)
        } else if (isSocialFeedCategory(activity)) {
            // Strip the social: prefix from feedId
            val socialFeedId = activity.feedId.substring(7)
            val feed = dbHelper.getSocialFeed(socialFeedId)
            if (feed == null) {
                Toast.makeText(context, R.string.profile_do_not_follow, Toast.LENGTH_SHORT).show()
            } else {
                UIUtils.startReadingActivity(FeedSet.singleSocialFeed(feed.userId, feed.username), activity.storyHash, context)
            }
        }
    }

    private fun isSocialFeedCategory(activity: ActivityDetails): Boolean {
        return activity.storyHash != null && (activity.category == ActivityDetails.Category.COMMENT_LIKE || activity.category == ActivityDetails.Category.COMMENT_REPLY || activity.category == ActivityDetails.Category.REPLY_REPLY || activity.category == ActivityDetails.Category.SHARED_STORY)
    }

    /**
     * Detects when user is close to the end of the current page and starts loading the next page
     * so the user will not have to wait (that much) for the next entries.
     *
     * @author Ognyan Bankov
     *
     *
     * https://github.com/ogrebgr/android_volley_examples/blob/master/src/com/github/volley_examples/Act_NetworkListView.java
     */
    inner class EndlessScrollListener : AbsListView.OnScrollListener {
        // how many entries earlier to start loading next page
        private val visibleThreshold = 5
        private var currentPage = 1
        private var previousTotal = 0
        private var loading = true

        override fun onScroll(view: AbsListView, firstVisibleItem: Int, visibleItemCount: Int, totalItemCount: Int) {
            if (loading) {
                if (totalItemCount > previousTotal) {
                    loading = false
                    previousTotal = totalItemCount
                    currentPage++
                }
            }
            if (!loading && totalItemCount - visibleItemCount <= firstVisibleItem + visibleThreshold) {
                // I load the next page of gigs using a background task,
                // but you can call any function here.
                loadPage(currentPage)
                loading = true
            }
        }

        override fun onScrollStateChanged(view: AbsListView, scrollState: Int) {}
    }
}