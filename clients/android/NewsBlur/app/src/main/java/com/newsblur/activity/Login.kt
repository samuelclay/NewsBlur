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
import com.newsblur.service.SubscriptionSyncService
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
                    onAuthCompleted = {
                        SubscriptionSyncService.schedule(this)

                        val startMain =
                            Intent(this, Main::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            }
                        startActivity(startMain)
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
}
