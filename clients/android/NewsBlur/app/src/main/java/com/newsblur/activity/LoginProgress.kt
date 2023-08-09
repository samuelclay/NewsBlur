package com.newsblur.activity

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.Window
import android.view.animation.AnimationUtils
import android.widget.Toast
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.databinding.ActivityLoginProgressBinding
import com.newsblur.network.APIManager
import com.newsblur.service.SubscriptionSyncService
import com.newsblur.util.PrefsUtils
import com.newsblur.util.UIUtils
import com.newsblur.util.executeAsyncTask
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class LoginProgress : FragmentActivity() {

    @Inject
    lateinit var apiManager: APIManager

    private lateinit var binding: ActivityLoginProgressBinding

    override fun onCreate(bundle: Bundle?) {
        PrefsUtils.applyThemePreference(this)
        super.onCreate(bundle)
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        binding = ActivityLoginProgressBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val username = intent.getStringExtra("username")
        val password = intent.getStringExtra("password")

        lifecycleScope.executeAsyncTask(
                onPreExecute = {
                    val a = AnimationUtils.loadAnimation(this, R.anim.text_up)
                    binding.loginLoggingIn.startAnimation(a)
                },
                doInBackground = {
                    val response = apiManager.login(username, password)
                    // pre-load the profile if the login was good
                    if (!response.isError) {
                        apiManager.updateUserProfile()
                    }
                    response
                },
                onPostExecute = {
                    if (!it.isError) {
                        val a = AnimationUtils.loadAnimation(this, R.anim.text_down)
                        binding.loginLoggingIn.setText(R.string.login_logged_in)
                        binding.loginLoggingInProgress.visibility = View.GONE
                        binding.loginLoggingIn.startAnimation(a)
                        val userImage = PrefsUtils.getUserImage(this)
                        if (userImage != null) {
                            binding.loginProfilePicture.visibility = View.VISIBLE
                            binding.loginProfilePicture.setImageBitmap(UIUtils.clipAndRound(userImage, true, false))
                        }
                        binding.loginFeedProgress.visibility = View.VISIBLE
                        val b = AnimationUtils.loadAnimation(this, R.anim.text_up)
                        binding.loginRetrievingFeeds.setText(R.string.login_retrieving_feeds)
                        binding.loginFeedProgress.startAnimation(b)

                        SubscriptionSyncService.schedule(this)

                        val startMain = Intent(this, Main::class.java)
                        startActivity(startMain)
                    } else {
                        UIUtils.safeToast(this, it.getErrorMessage(getString(R.string.login_message_error)), Toast.LENGTH_LONG)
                        startActivity(Intent(this, Login::class.java))
                    }
                }
        )
    }
}