package com.newsblur.activity

import android.content.res.Configuration
import android.os.Bundle
import android.view.Window
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.commit
import com.newsblur.R
import com.newsblur.fragment.LoginRegisterFragment

class Login : FragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        when (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) {
            Configuration.UI_MODE_NIGHT_YES -> setTheme(R.style.NewsBlurDarkTheme)
            Configuration.UI_MODE_NIGHT_NO -> setTheme(R.style.NewsBlurTheme)
            Configuration.UI_MODE_NIGHT_UNDEFINED -> setTheme(R.style.NewsBlurTheme)
        }
        super.onCreate(savedInstanceState)

        requestWindowFeature(Window.FEATURE_NO_TITLE)
        setContentView(R.layout.activity_login)

        if (supportFragmentManager.findFragmentByTag(LoginRegisterFragment::class.java.name) == null) {
            supportFragmentManager.commit {
                val login = LoginRegisterFragment()
                add(R.id.login_container, login, LoginRegisterFragment::class.java.name)
            }
        }
    }
}
