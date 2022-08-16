package com.newsblur.activity

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.databinding.ActivityShareExternalStoryBinding
import com.newsblur.network.APIManager
import com.newsblur.util.*
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class ShareExternalStoryActivity : AppCompatActivity() {

    @Inject
    lateinit var apiManager: APIManager

    private var storyTitle: String? = null
    private var storyUrl: String? = null

    private lateinit var binding: ActivityShareExternalStoryBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        PrefsUtils.applyTranslucentThemePreference(this)
        super.onCreate(savedInstanceState)
        binding = ActivityShareExternalStoryBinding.inflate(layoutInflater)
        setContentView(binding.root)

        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            handleIntent()
        } else {
            finishWithToast("NewsBlur invalid intent action!")
        }
    }

    private fun handleIntent() {
        storyTitle = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        storyUrl = intent.getStringExtra(Intent.EXTRA_TEXT)

        if (!storyTitle.isNullOrEmpty() && !storyUrl.isNullOrEmpty()) {
            binding.textTitle.text = getString(R.string.share_save_newsblur, storyTitle)

            binding.textCancel.setOnClickListener { finish() }
            binding.textShare.setOnClickListener { shareStory(binding.inputComment.text.toString()) }
            binding.textSave.setOnClickListener { saveStory() }
        } else {
            finishWithToast("NewsBlur story metadata unrecognized")
        }
    }

    private fun shareStory(comment: String) {
        lifecycleScope.executeAsyncTask(
                onPreExecute = {
                    binding.progressIndicator.setViewVisible()
                    binding.containerButtons.setViewGone()
                },
                doInBackground = {
                    apiManager.shareExternalStory(storyTitle!!, storyUrl!!, comment)
                },
                onPostExecute = { response ->
                    if (!response.isError) finishWithToast("NewsBlur shared $storyTitle successfully!")
                    else finishWithToast("NewsBlur shared $storyTitle unsuccessfully!")
                }
        )
    }

    private fun saveStory() {
        lifecycleScope.executeAsyncTask(
                onPreExecute = {
                    binding.progressIndicator.setViewVisible()
                    binding.containerButtons.setViewGone()
                },
                doInBackground = {
                    apiManager.saveExternalStory(storyTitle!!, storyUrl!!)
                },
                onPostExecute = { response ->
                    if (!response.isError) finishWithToast("NewsBlur saved $storyTitle successfully!")
                    else finishWithToast("NewsBlur saved $storyTitle unsuccessfully!")
                }
        )
    }

    private fun finishWithToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        finish()
    }
}