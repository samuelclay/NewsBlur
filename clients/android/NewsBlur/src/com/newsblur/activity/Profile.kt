package com.newsblur.activity

import android.os.Bundle
import android.text.TextUtils
import android.view.MenuItem
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.databinding.ActivityProfileBinding
import com.newsblur.di.IconLoader
import com.newsblur.fragment.ProfileDetailsFragment
import com.newsblur.network.APIManager
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefsUtils
import com.newsblur.util.UIUtils
import com.newsblur.util.executeAsyncTask
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class Profile : NbActivity() {

    @Inject
    lateinit var apiManager: APIManager

    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    private val detailsTag = "details"
    private var detailsFragment: ProfileDetailsFragment? = null
    private var activityDetailsPagerAdapter: ActivityDetailsPagerAdapter? = null
    private var userId: String? = null

    private lateinit var binding: ActivityProfileBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityProfileBinding.inflate(layoutInflater)
        setContentView(binding.root)
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.profile), true)

        userId = if (savedInstanceState == null) {
            intent.getStringExtra(USER_ID)
        } else {
            savedInstanceState.getString(USER_ID)
        }


        if (supportFragmentManager.findFragmentByTag(detailsTag) == null) {
            val detailsTransaction = supportFragmentManager.beginTransaction()
            detailsFragment = ProfileDetailsFragment()
            detailsTransaction.add(R.id.profile_details, detailsFragment!!, detailsTag)
            detailsTransaction.commit()

            activityDetailsPagerAdapter = ActivityDetailsPagerAdapter(supportFragmentManager, this)
            binding.activityDetailsPager.adapter = activityDetailsPagerAdapter
        } else {
            detailsFragment = supportFragmentManager.findFragmentByTag(detailsTag) as ProfileDetailsFragment
        }
        loadUserDetails()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        userId?.let { outState.putString(USER_ID, it) }
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                finish()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }

    private fun loadUserDetails() {
        lifecycleScope.executeAsyncTask(
                onPreExecute = {
                    if (TextUtils.isEmpty(userId) && detailsFragment != null) {
                        detailsFragment!!.setUser(this, PrefsUtils.getUserDetails(this), true)
                    }
                },
                doInBackground = {
                    if (!TextUtils.isEmpty(userId)) {
                        val intentUserId = intent.getStringExtra(USER_ID)
                        apiManager.getUser(intentUserId).user
                    } else {
                        apiManager.updateUserProfile()
                        PrefsUtils.getUserDetails(this)
                    }
                },
                onPostExecute = { userDetails ->
                    if (userDetails != null && detailsFragment != null && activityDetailsPagerAdapter != null) {
                        detailsFragment!!.setUser(this, userDetails, TextUtils.isEmpty(userId))
                        activityDetailsPagerAdapter!!.setUser(userDetails, iconLoader)
                    }
                }
        )
    }

    companion object {
        const val USER_ID = "user_id"
    }
}