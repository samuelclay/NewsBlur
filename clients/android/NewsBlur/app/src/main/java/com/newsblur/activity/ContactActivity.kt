package com.newsblur.activity

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.newsblur.R
import com.newsblur.compose.ContactScreen
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.EdgeToEdgeUtil.applyTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class ContactActivity : ComponentActivity() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        applyTheme(prefsRepo.getSelectedTheme())
        setContent {
            NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                ContactScreen(
                    onBack = { finish() },
                    onEmail = {
                        openContactLink(
                            Intent(Intent.ACTION_SENDTO, Uri.fromParts("mailto", getString(R.string.contact_email), null)),
                            R.string.contact_no_email_app,
                        )
                    },
                    onWebsite = {
                        openContactLink(
                            Intent(Intent.ACTION_VIEW, Uri.parse(getString(R.string.contact_website))),
                            R.string.contact_no_browser,
                        )
                    },
                )
            }
        }
    }

    private fun openContactLink(intent: Intent, errorMessage: Int) {
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, errorMessage, Toast.LENGTH_LONG).show()
        }
    }
}
