package com.newsblur.activity

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.core.net.toUri
import androidx.fragment.app.FragmentActivity
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.AppConstants
import com.newsblur.util.DailyBriefingDeepLink
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class LoginActivity : FragmentActivity() {
    private val account: com.newsblur.onboarding.AccountViewModel by viewModels()

    @Inject
    lateinit var prefsRepo: PrefsRepo

    @SuppressLint("UseKtx")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        intent?.data?.let(account::callback)
        val variant = prefsRepo.getSelectedTheme().toVariant()
        setContent {
            NewsBlurTheme(variant = variant) {
                com.newsblur.onboarding.AccountScreen(
                    model = account,
                    onAuthenticated = ::onAuthCompleted,
                    onForgot = ::onOpenForgotPassword,
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.let(account::callback)
    }

    private fun onAuthCompleted(setup: Boolean) {
        if (setup) {
            startActivity(Intent(this, OnboardingActivity::class.java).putExtra("initial_setup", true))
            finish()
            return
        }

        val startDestination =
            DailyBriefingDeepLink.createLaunchIntent(this, intent?.data)
                ?: Intent(this, Main::class.java)

        startDestination.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        startActivity(startDestination)
        finish()
    }

    private fun onOpenForgotPassword() {
        try {
            UIUtils.handleUri(this, prefsRepo, AppConstants.FORGOT_PASWORD_URL.toUri())
        } catch (_: Exception) {
        }
    }
}
