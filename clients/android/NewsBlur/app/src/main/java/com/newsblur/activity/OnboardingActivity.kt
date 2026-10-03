package com.newsblur.activity

import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.di.ThumbnailLoader
import com.newsblur.onboarding.SetupScreen
import com.newsblur.onboarding.SetupViewModel
import com.newsblur.util.ImageLoader
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class OnboardingActivity : NbActivity() {
    private val model: SetupViewModel by viewModels()

    @Inject @ThumbnailLoader
    lateinit var thumbnails: ImageLoader

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                SetupScreen(model, prefsRepo.getResolvedTheme(this), thumbnails, onClose = { leave(false) }, onComplete = { leave(true) })
            }
        }
    }

    private fun leave(complete: Boolean) {
        if (complete) prefsRepo.completeOnboarding()
        if (intent.getBooleanExtra("initial_setup", false)) startActivity(Intent(this, Main::class.java))
        finish()
    }
}
