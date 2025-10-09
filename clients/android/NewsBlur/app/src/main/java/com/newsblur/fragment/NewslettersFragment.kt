package com.newsblur.fragment

import android.app.Dialog
import android.content.ClipData
import android.content.ClipboardManager
import android.os.Bundle
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.DialogFragment
import com.newsblur.R
import com.newsblur.databinding.NewsletterDialogBinding
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.setViewGone
import com.newsblur.util.setViewVisible
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class NewslettersFragment : DialogFragment() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val binding = NewsletterDialogBinding.inflate(layoutInflater)
        val emailAddress = generateEmail()

        binding.txtEmail.text = emailAddress
        binding.btnSetup.setOnClickListener {
            binding.btnSetup.setViewGone()
            binding.txtSetup.setViewVisible()
        }

        return AlertDialog
            .Builder(requireContext())
            .apply {
                setView(binding.root)
                setPositiveButton(android.R.string.ok, null)
                setNegativeButton(R.string.copy_email) { _, _ ->
                    copyToClipboard(emailAddress)
                }
            }.create()
    }

    private fun generateEmail(): String {
        val username = prefsRepo.getUserName()
        val extToken = prefsRepo.getExtToken()
        return if (username.isNullOrBlank() || extToken.isNullOrBlank()) {
            "Error generating forwarding email address"
        } else {
            "$username-$extToken@newsletters.newsblur.com"
        }
    }

    private fun copyToClipboard(message: String) {
        val clipboardManager = requireContext().getSystemService(ClipboardManager::class.java)
        val clipData = ClipData.newPlainText("NewsBlur email forwarding", message)
        clipboardManager.setPrimaryClip(clipData)
    }
}
