package com.newsblur.activity

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.fragment.app.FragmentActivity
import com.newsblur.compose.LoginScreen
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.AppConstants
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class Login : FragmentActivity() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    @SuppressLint("UseKtx")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val variant = prefsRepo.getSelectedTheme().toVariant()
        setContent {
            NewsBlurTheme(variant = variant) {
                LoginScreen(
                    prefsRepo = prefsRepo,
                    onStartLoginProgress = ::startLogin,
                    onStartRegisterProgress = { username, password, email ->
                        startActivity(
                            Intent(this, RegisterProgress::class.java).apply {
                                putExtra("username", username)
                                putExtra("password", password)
                                putExtra("email", email)
                            },
                        )
                    },
                    onOpenForgotPassword = {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(AppConstants.FORGOT_PASWORD_URL)))
                        } catch (_: Exception) {
                        }
                    },
                )
            }
        }
    }

    private fun startLogin(
        username: String,
        password: String,
    ) {
        startActivity(
            Intent(this, LoginProgress::class.java).apply {
                putExtra("username", username)
                putExtra("password", password)
            },
        )
    }
}
