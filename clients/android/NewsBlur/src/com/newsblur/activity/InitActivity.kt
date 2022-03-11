package com.newsblur.activity

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.service.SubscriptionSyncService
import com.newsblur.util.*
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * The very first activity we launch. Checks to see if there is a user logged in yet and then
 * either loads the Main UI or a Login screen as needed.  Also responsible for warming up the
 * DB connection used by all other Activities.
 */
@AndroidEntryPoint
class InitActivity : AppCompatActivity() {

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)

        // Keep the splash screen visible for this Activity
        splashScreen.setKeepOnScreenCondition { true }

        lifecycleScope.executeAsyncTask(doInBackground = { start() })
        Log.i(this, "cold launching version " + PrefsUtils.getVersion(this))
    }

    private fun start() {
        // it is safe to call repeatedly because creating an existing notification performs
        // no operation
        NotificationUtils.createNotificationChannel(this)

        // now before there is any chance at all of an activity hitting the DB and crashing when it
        // cannot find new tables or columns right after an app upgrade, check to see if the DB
        // needs an upgrade
        upgradeCheck()

        // see if a user is already logged in; if so, jump to the Main activity
        userAuthCheck()
    }

    private fun userAuthCheck() {
        if (PrefsUtils.hasCookie(this)) {
            SubscriptionSyncService.schedule(this)
            val mainIntent = Intent(this, Main::class.java)
            startActivity(mainIntent)
        } else {
            val loginIntent = Intent(this, Login::class.java)
            startActivity(loginIntent)
        }
    }

    private fun upgradeCheck() {
        val upgrade = PrefsUtils.checkForUpgrade(this)
        if (upgrade) {
            dbHelper.dropAndRecreateTables()
            // don't actually unset the upgrade flag, the sync service will do this same check and
            // update everything
        }
    }
}