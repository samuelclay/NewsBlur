package com.newsblur.activity

import android.content.Intent
import android.os.Bundle
import android.view.animation.AnimationUtils
import android.widget.Toast
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.databinding.ActivityRegisterProgressBinding
import com.newsblur.network.AuthApi
import com.newsblur.network.domain.RegisterResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.EdgeToEdgeUtil.applyTheme
import com.newsblur.util.EdgeToEdgeUtil.applyView
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
    lateinit var authApi: AuthApi

    @Inject
    lateinit var prefsRepo: PrefsRepo

    private lateinit var binding: ActivityRegisterProgressBinding

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
        applyTheme(prefsRepo.getSelectedTheme())
        binding = ActivityRegisterProgressBinding.inflate(layoutInflater)
        applyView(binding)

        val username = intent.getStringExtra("username")
        val password = intent.getStringExtra("password")
        val email = intent.getStringExtra("email")

        binding.progressLogo.startAnimation(AnimationUtils.loadAnimation(this, R.anim.rotate))

        lifecycleScope.executeAsyncTask(
                doInBackground = {
                    authApi.signup(
                            username.orEmpty(),
                            password.orEmpty(),
                            email.orEmpty(),
                    )
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