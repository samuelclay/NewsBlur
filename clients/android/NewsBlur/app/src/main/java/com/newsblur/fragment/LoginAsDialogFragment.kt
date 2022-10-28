package com.newsblur.fragment

import android.app.Dialog
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.DialogFragment
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.activity.Main
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.LoginasDialogBinding
import com.newsblur.network.APIManager
import com.newsblur.util.PrefsUtils
import com.newsblur.util.UIUtils
import com.newsblur.util.executeAsyncTask
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class LoginAsDialogFragment : DialogFragment() {

    @Inject
    lateinit var apiManager: APIManager

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val builder = AlertDialog.Builder(requireActivity())
        builder.setTitle(R.string.loginas_title)
        val layoutInflater = LayoutInflater.from(requireActivity())
        val view = layoutInflater.inflate(R.layout.loginas_dialog, null)
        val binding: LoginasDialogBinding = LoginasDialogBinding.bind(view)

        builder.setView(binding.root)
        builder.setPositiveButton(R.string.alert_dialog_ok) { _, _ ->
            val username = binding.usernameField.text.toString()
            lifecycleScope.executeAsyncTask(
                    doInBackground = {
                        val result = apiManager.loginAs(username)
                        if (result) {
                            PrefsUtils.clearPrefsAndDbForLoginAs(requireActivity(), dbHelper)
                            apiManager.updateUserProfile()
                        }
                        result
                    },
                    onPostExecute = {
                        if (it) {
                            val startMain = Intent(requireActivity(), Main::class.java)
                            requireActivity().startActivity(startMain)
                        } else {
                            UIUtils.safeToast(requireActivity(), "Login as $username failed", Toast.LENGTH_LONG)
                        }
                    }
            )
            dismiss()
        }
        builder.setNegativeButton(R.string.alert_dialog_cancel) { _, _ -> dismiss() }
        return builder.create()
    }
}