package com.newsblur.fragment

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.text.TextUtils
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.Toast
import androidx.fragment.app.Fragment
import com.newsblur.R
import com.newsblur.activity.LoginProgress
import com.newsblur.activity.RegisterProgress
import com.newsblur.databinding.FragmentLoginregisterBinding
import com.newsblur.network.APIConstants
import com.newsblur.util.AppConstants
import com.newsblur.util.PrefsUtils

class LoginRegisterFragment : Fragment() {

    private lateinit var binding: FragmentLoginregisterBinding

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        val v = inflater.inflate(R.layout.fragment_loginregister, container, false)
        binding = FragmentLoginregisterBinding.bind(v)

        binding.loginPassword.setOnEditorActionListener { _, actionId: Int, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                logIn()
            }
            false
        }
        binding.registrationEmail.setOnEditorActionListener { _, actionId: Int, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                signUp()
            }
            false
        }
        return v
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.loginButton.setOnClickListener { logIn() }
        binding.registrationButton.setOnClickListener { signUp() }
        binding.loginChangeToLogin.setOnClickListener { showLogin() }
        binding.loginChangeToRegister.setOnClickListener { showRegister() }
        binding.loginForgotPassword.setOnClickListener { launchForgotPasswordPage() }
        binding.loginCustomServer.setOnClickListener { showCustomServer(true) }
        binding.buttonResetUrl.setOnClickListener { showCustomServer(false) }
        val customServerUrl = PrefsUtils.getCustomSever(requireContext())
        if (!TextUtils.isEmpty(customServerUrl)) {
            binding.loginCustomServerValue.setText(customServerUrl)
            showCustomServer(true)
        }
    }

    private fun logIn() {
        if (!TextUtils.isEmpty(binding.loginUsername.text.toString())) {
            // set the custom server endpoint before any API access, even the cookie fetch.
            val customServerValue = binding.loginCustomServerValue.text.toString()
            if (!TextUtils.isEmpty(customServerValue) && customServerValue.startsWith("https://")) {
                APIConstants.setCustomServer(customServerValue)
                PrefsUtils.saveCustomServer(activity, customServerValue)
            } else if (!TextUtils.isEmpty(customServerValue)) {
                Toast.makeText(requireActivity(), R.string.login_custom_server_scheme_error, Toast.LENGTH_LONG).show()
                return
            }

            val loginIntent = Intent(activity, LoginProgress::class.java).apply {
                putExtra("username", binding.loginUsername.text.toString())
                putExtra("password", binding.loginPassword.text.toString())
            }
            startActivity(loginIntent)
        }
    }

    private fun signUp() {
        val registerIntent = Intent(activity, RegisterProgress::class.java).apply {
            putExtra("username", binding.registrationUsername.text.toString())
            putExtra("password", binding.registrationPassword.text.toString())
            putExtra("email", binding.registrationEmail.text.toString())
        }
        startActivity(registerIntent)
    }

    private fun showLogin() {
        binding.loginViewswitcher.showPrevious()
    }

    private fun showRegister() {
        binding.loginViewswitcher.showNext()
    }

    private fun launchForgotPasswordPage() {
        try {
            val i = Intent(Intent.ACTION_VIEW)
            i.data = Uri.parse(AppConstants.FORGOT_PASWORD_URL)
            startActivity(i)
        } catch (e: Exception) {
            Log.wtf(this.javaClass.name, "device cannot even open URLs to report feedback")
        }
    }

    private fun showCustomServer(isVisible: Boolean) {
        binding.loginCustomServer.visibility = if (isVisible) View.GONE else View.VISIBLE
        binding.loginCustomServerValue.visibility = if (isVisible) View.VISIBLE else View.GONE
        binding.buttonResetUrl.visibility = if (isVisible) View.VISIBLE else View.GONE
        binding.textCustomServer.visibility = if (isVisible) View.VISIBLE else View.GONE

        if (!isVisible) {
            binding.loginCustomServerValue.setText("")
            APIConstants.unsetCustomServer()
            PrefsUtils.clearCustomServer(context)
        }
    }
}