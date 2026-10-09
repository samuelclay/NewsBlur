package com.newsblur.activity

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.core.net.toUri
import androidx.core.view.WindowCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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

    @Inject lateinit var dbHelper: com.newsblur.database.BlurDatabaseHelper

    @SuppressLint("UseKtx")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val deleting = intent.getBooleanExtra("manage_account", false)
        val resolvedTheme = prefsRepo.getResolvedTheme(this)
        val light = deleting && (resolvedTheme == com.newsblur.util.PrefConstants.ThemeValue.LIGHT ||
            resolvedTheme == com.newsblur.util.PrefConstants.ThemeValue.SEPIA)
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = light
            isAppearanceLightNavigationBars = light
        }
        intent?.data?.let(account::callback)
        val variant = prefsRepo.getSelectedTheme().toVariant()
        setContent {
            NewsBlurTheme(variant = variant, dynamic = false) {
                val state by account.state.collectAsStateWithLifecycle()
                if (state.deleting) {
                    com.newsblur.onboarding.AccountDeletionScreen(state, account, prefsRepo.getResolvedTheme(this), { finish() }, {
                        prefsRepo.logout(this, dbHelper)
                        finish()
                    })
                    com.newsblur.onboarding.SocialBrowserEffect(account, state)
                } else {
                    com.newsblur.onboarding.AccountScreen(
                        model = account,
                        onAuthenticated = ::onAuthCompleted,
                        onForgot = ::onOpenForgotPassword,
                    )
                }
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
