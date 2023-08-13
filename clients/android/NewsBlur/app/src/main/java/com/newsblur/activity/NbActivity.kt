package com.newsblur.activity

import android.content.IntentFilter
import androidx.appcompat.app.AppCompatActivity
import com.newsblur.util.PrefConstants.ThemeValue
import android.os.Bundle
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.util.PrefsUtils
import com.newsblur.util.UIUtils
import com.newsblur.service.NBSyncReceiver
import com.newsblur.util.FeedUtils
import com.newsblur.util.Log
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

/**
 * The base class for all Activities in the NewsBlur app.  Handles enforcement of
 * login state and tracking of sync/update broadcasts.
 */
@AndroidEntryPoint
open class NbActivity : AppCompatActivity() {

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    private var uniqueLoginKey: String? = null
    private var lastTheme: ThemeValue? = null

    // Facilitates the db updates by the sync service on the UI
    private val serviceSyncReceiver = object : NBSyncReceiver() {
        override fun handleUpdateType(updateType: Int) {
            runOnUiThread { handleUpdate(updateType) }
        }
    }

    override fun onCreate(bundle: Bundle?) {
        Log.offerContext(this)
        Log.d(this, "onCreate")

        // this is not redundant to the applyThemePreference() call in onResume. the theme needs to be set
        // before onCreate() in order to work
        PrefsUtils.applyThemePreference(this)
        lastTheme = PrefsUtils.getSelectedTheme(this)

        super.onCreate(bundle)

        // in rare cases of process interruption or DB corruption, an activity can launch without valid
        // login creds.  redirect the user back to the loging workflow.
        if (PrefsUtils.getUserId(this) == null) {
            Log.e(this, "post-login activity launched without valid login.")
            PrefsUtils.logout(this, dbHelper)
            finish()
        }

        bundle?.let {
            uniqueLoginKey = it.getString(UNIQUE_LOGIN_KEY)
        }

        if (uniqueLoginKey == null) {
            uniqueLoginKey = PrefsUtils.getUniqueLoginKey(this)
        }

        finishIfNotLoggedIn()
    }

    override fun onResume() {
        Log.d(this, "onResume" + UIUtils.getMemoryUsageDebug(this))
        super.onResume()
        finishIfNotLoggedIn()

        // is is possible that another activity changed the theme while we were on the backstack
        val currentSelectedTheme = PrefsUtils.getSelectedTheme(this)
        if (lastTheme != currentSelectedTheme) {
            lastTheme = currentSelectedTheme
            PrefsUtils.applyThemePreference(this)
            UIUtils.restartActivity(this)
        }
        registerReceiver(serviceSyncReceiver, IntentFilter().apply {
            addAction(NBSyncReceiver.NB_SYNC_ACTION)
        })
    }

    override fun onPause() {
        Log.d(this.javaClass.name, "onPause")
        super.onPause()
        unregisterReceiver(serviceSyncReceiver)
    }

    private fun finishIfNotLoggedIn() {
        val currentLoginKey = PrefsUtils.getUniqueLoginKey(this)
        if (currentLoginKey == null || currentLoginKey != uniqueLoginKey) {
            Log.d(this.javaClass.name, "This activity was for a different login. finishing it.")
            finish()
        }
    }

    override fun onSaveInstanceState(savedInstanceState: Bundle) {
        Log.d(this, "onSave")
        savedInstanceState.putString(UNIQUE_LOGIN_KEY, uniqueLoginKey)
        super.onSaveInstanceState(savedInstanceState)
    }

    /**
     * Pokes the sync service to perform any pending sync actions.
     */
    protected fun triggerSync() {
        FeedUtils.triggerSync(this)
    }

    /**
     * Called on each NB activity after the DB has been updated by the sync service.
     *
     * @param updateType one or more of the UPDATE_* flags in this class to indicate the
     * type of update being broadcast.
     */
    protected open fun handleUpdate(updateType: Int) {
        Log.w(this, "activity doesn't implement handleUpdate")
    }
}

private const val UNIQUE_LOGIN_KEY = "uniqueLoginKey"