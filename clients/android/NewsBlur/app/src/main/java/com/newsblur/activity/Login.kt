package com.newsblur.activity

import android.os.Bundle
import android.view.Window
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.commit
import com.newsblur.R
import com.newsblur.databinding.ActivityLoginBinding
import com.newsblur.fragment.LoginRegisterFragment
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.EdgeToEdgeUtil.applyTheme
import com.newsblur.util.EdgeToEdgeUtil.applyView
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class Login : FragmentActivity() {

    @Inject
    lateinit var prefsRepo: PrefsRepo

    override fun onCreate(savedInstanceState: Bundle?) {
        applyTheme(prefsRepo.getSelectedTheme())
        super.onCreate(savedInstanceState)

        requestWindowFeature(Window.FEATURE_NO_TITLE)
        applyView(ActivityLoginBinding.inflate(layoutInflater))

        if (supportFragmentManager.findFragmentByTag(LoginRegisterFragment::class.java.name) == null) {
            supportFragmentManager.commit {
                val login = LoginRegisterFragment()
                add(R.id.content, login, LoginRegisterFragment::class.java.name)
            }
        }
    }
}
