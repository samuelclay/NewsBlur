package com.newsblur.activity

import android.content.Intent
import android.os.Bundle
import android.view.animation.AnimationUtils
import android.widget.Toast
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.databinding.ActivityRegisterProgressBinding
import com.newsblur.network.APIManager
import com.newsblur.network.domain.RegisterResponse
import com.newsblur.util.PrefsUtils
import com.newsblur.util.executeAsyncTask
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * Show progress screen while registering request is being processed. This
 * Activity doesn't extend NbActivity because it is one of the few
 * Activities that will be shown while the user is still logged out.
 */
@AndroidEntryPoint
class RegisterProgress : FragmentActivity() {

    @Inject
    lateinit var apiManager: APIManager

    private lateinit var binding: ActivityRegisterProgressBinding

    override fun onCreate(bundle: Bundle?) {
        PrefsUtils.applyThemePreference(this)
        super.onCreate(bundle)
        binding = ActivityRegisterProgressBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val username = intent.getStringExtra("username")
        val password = intent.getStringExtra("password")
        val email = intent.getStringExtra("email")

        binding.progressLogo.startAnimation(AnimationUtils.loadAnimation(this, R.anim.rotate))

        lifecycleScope.executeAsyncTask(
                doInBackground = {
                    apiManager.signup(username, password, email)
                },
                onPostExecute = {
                    if (it.authenticated) showAuth()
                    else showError(it)
                }
        )
    }

    private fun showAuth() {
        startActivity(Intent(this, Main::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        })
    }

    private fun showError(response: RegisterResponse) {
        val errorMessage = response.errorMessage
                ?: resources.getString(R.string.register_message_error)
        Toast.makeText(this, errorMessage, Toast.LENGTH_LONG).show()
        startActivity(Intent(this, Login::class.java))
    }
}