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
import com.newsblur.network.AuthApi
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.SubscriptionSyncService
import com.newsblur.util.EdgeToEdgeUtil.applyTheme
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.UIUtils
import com.newsblur.util.executeAsyncTask
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class LoginProgress : FragmentActivity() {
    @Inject
    lateinit var userApi: UserApi

    @Inject
    lateinit var authApi: AuthApi

    @Inject
    lateinit var prefsRepo: PrefsRepo

    private lateinit var binding: ActivityLoginProgressBinding

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
        applyTheme(prefsRepo.getSelectedTheme())
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        binding = ActivityLoginProgressBinding.inflate(layoutInflater)
        applyView(binding)

        val username = intent.getStringExtra("username")
        val password = intent.getStringExtra("password")

        lifecycleScope.executeAsyncTask(
            onPreExecute = {
                val a = AnimationUtils.loadAnimation(this, R.anim.text_up)
                binding.loginLoggingIn.startAnimation(a)
            },
            doInBackground = {
                val response =
                    authApi.login(
                        username.orEmpty(),
                        password.orEmpty(),
                    )
                // pre-load the profile if the login was good
                if (!response.isError) {
                    userApi.updateUserProfile()
                }
                val roundedUserImage =
                    prefsRepo.getUserImage(this)?.let { userImage ->
                        UIUtils.clipAndRound(userImage, true, false)
                    }
                response to roundedUserImage
            },
            onPostExecute = { (response, userImage) ->
                if (!response.isError) {
                    val a = AnimationUtils.loadAnimation(this, R.anim.text_down)
                    binding.loginLoggingIn.setText(R.string.login_logged_in)
                    binding.loginLoggingInProgress.visibility = View.GONE
                    binding.loginLoggingIn.startAnimation(a)
                    if (userImage != null) {
                        binding.loginProfilePicture.visibility = View.VISIBLE
                        binding.loginProfilePicture.setImageBitmap(userImage)
                    }
                    binding.loginFeedProgress.visibility = View.VISIBLE
                    val b = AnimationUtils.loadAnimation(this, R.anim.text_up)
                    binding.loginRetrievingFeeds.setText(R.string.login_retrieving_feeds)
                    binding.loginFeedProgress.startAnimation(b)

                    SubscriptionSyncService.schedule(this)

                    val startMain = Intent(this, Main::class.java)
                    startActivity(startMain)
                } else {
                    Toast.makeText(this, response.getErrorMessage(getString(R.string.login_message_error)), Toast.LENGTH_LONG).show()
                    startActivity(Intent(this, Login::class.java))
                }
            },
        )
    }
}
