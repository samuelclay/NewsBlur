package com.newsblur.fragment

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.activity.AddFacebook
import com.newsblur.activity.AddTwitter
import com.newsblur.databinding.FragmentAddsocialBinding
import com.newsblur.network.APIManager
import com.newsblur.util.executeAsyncTask
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class AddSocialFragment : Fragment() {

    @Inject
    lateinit var apiManager: APIManager

    private lateinit var binding: FragmentAddsocialBinding

    private var twitterAuthed = false
    private var facebookAuthed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        retainInstance = true
    }

    fun setTwitterAuthed() {
        twitterAuthed = true
        authCheck()
    }

    fun setFacebookAuthed() {
        facebookAuthed = true
        authCheck()
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        val view = inflater.inflate(R.layout.fragment_addsocial, null)
        binding = FragmentAddsocialBinding.bind(view)
        binding.addsocialTwitter.setOnClickListener {
            val i = Intent(activity, AddTwitter::class.java)
            startActivityForResult(i, 0)
        }
        binding.addsocialFacebook.setOnClickListener {
            val i = Intent(activity, AddFacebook::class.java)
            startActivityForResult(i, 0)
        }
        authCheck()
        binding.addsocialAutofollowCheckbox.setOnCheckedChangeListener { _, checked ->
            lifecycleScope.executeAsyncTask(
                    doInBackground = {
                        apiManager.setAutoFollow(checked)
                    }
            )
        }
        return view
    }

    private fun authCheck() {
        if (twitterAuthed) {
            binding.addsocialTwitterText.text = "Added Twitter friends!"
            binding.addsocialTwitter.isEnabled = false
        }
        if (facebookAuthed) {
            binding.addsocialFacebookText.text = "Added Facebook friends!"
            binding.addsocialFacebook.isEnabled = false
        }
    }
}