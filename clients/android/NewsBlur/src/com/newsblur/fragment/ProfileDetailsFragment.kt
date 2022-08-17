package com.newsblur.fragment

import android.content.Context
import android.os.Bundle
import android.text.TextUtils
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.databinding.FragmentProfiledetailsBinding
import com.newsblur.di.IconLoader
import com.newsblur.domain.UserDetails
import com.newsblur.network.APIManager
import com.newsblur.util.FeedUtils
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefsUtils
import com.newsblur.util.UIUtils
import com.newsblur.util.executeAsyncTask
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class ProfileDetailsFragment : Fragment() {

    @Inject
    lateinit var apiManager: APIManager

    @IconLoader
    @Inject
    lateinit var iconLoader: ImageLoader

    private var user: UserDetails? = null
    private var viewingSelf = false

    private lateinit var binding: FragmentProfiledetailsBinding

    fun setUser(context: Context, user: UserDetails?, viewingSelf: Boolean) {
        this.user = user
        this.viewingSelf = viewingSelf
        if (::binding.isInitialized) {
            setUserFields(context)
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        val view = inflater.inflate(R.layout.fragment_profiledetails, container, false)
        binding = FragmentProfiledetailsBinding.bind(view)
        binding.profileFollowButton.setOnClickListener { followUser() }
        binding.profileUnfollowButton.setOnClickListener { unfollowUser() }
        user?.let { setUserFields(requireContext()) }
        return view
    }

    private fun setUserFields(context: Context?) {
        binding.profileUsername.text = user!!.username
        if (!TextUtils.isEmpty(user!!.bio)) {
            binding.profileBio.text = user!!.bio
        } else {
            binding.profileBio.visibility = View.INVISIBLE
        }
        if (!TextUtils.isEmpty(user!!.location)) {
            binding.profileLocation.text = user!!.location
        } else {
            binding.profileLocation.visibility = View.INVISIBLE
            binding.profileLocationIcon.visibility = View.INVISIBLE
        }
        if (!TextUtils.isEmpty(user!!.website)) {
            binding.profileWebsite.text = user!!.website
        } else {
            binding.profileWebsite.visibility = View.GONE
        }
        binding.profileUserStatistics.profileSharedcount.text = user!!.sharedStoriesCount.toString()
        binding.profileUserStatistics.profileFollowercount.text = user!!.followerCount.toString()
        binding.profileUserStatistics.profileFollowingcount.text = user!!.followingCount.toString()
        if (!viewingSelf) {
            iconLoader.displayImage(user!!.photoUrl, binding.profilePicture)
            if (user!!.followedByYou) {
                binding.profileUnfollowButton.visibility = View.VISIBLE
                binding.profileFollowButton.visibility = View.GONE
            } else {
                binding.profileUnfollowButton.visibility = View.GONE
                binding.profileFollowButton.visibility = View.VISIBLE
            }
        } else {
            binding.profileFollowButton.visibility = View.GONE
            var userPicture = PrefsUtils.getUserImage(context)
            // seems to sometimes be an error loading the picture so prevent
            // force close if null returned
            if (userPicture != null) {
                userPicture = UIUtils.clipAndRound(userPicture, true, false)
                binding.profilePicture.setImageBitmap(userPicture)
            }
        }
    }

    private fun followUser() {
        lifecycleScope.executeAsyncTask(
                onPreExecute = {
                    binding.profileFollowButton.isEnabled = false
                },
                doInBackground = {
                    apiManager.followUser(user!!.userId)
                },
                onPostExecute = {
                    binding.profileFollowButton.isEnabled = true
                    if (it) {
                        user!!.followedByYou = true
                        binding.profileFollowButton.visibility = View.GONE
                        binding.profileUnfollowButton.visibility = View.VISIBLE
                    } else {
                        val alertDialog = AlertDialogFragment.newAlertDialogFragment(resources.getString(R.string.follow_error))
                        alertDialog.show(parentFragmentManager, "fragment_edit_name")
                    }
                }
        )
    }

    private fun unfollowUser() {
        lifecycleScope.executeAsyncTask(
                onPreExecute = {
                    binding.profileUnfollowButton.isEnabled = false
                },
                doInBackground = {
                    apiManager.unfollowUser(user!!.userId)
                },
                onPostExecute = {
                    binding.profileUnfollowButton.isEnabled = true
                    if (it) {
                        user!!.followedByYou = false
                        binding.profileUnfollowButton.visibility = View.GONE
                        binding.profileFollowButton.visibility = View.VISIBLE
                    } else {
                        val alertDialog = AlertDialogFragment.newAlertDialogFragment(resources.getString(R.string.unfollow_error))
                        alertDialog.show(parentFragmentManager, "fragment_edit_name")
                    }
                }
        )
    }
}