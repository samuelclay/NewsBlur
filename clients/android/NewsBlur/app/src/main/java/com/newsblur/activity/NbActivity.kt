package com.newsblur.activity

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.NBSync
import com.newsblur.service.NbSyncManager
import com.newsblur.util.EdgeToEdgeUtil.applyTheme
import com.newsblur.util.FeedUtils
import com.newsblur.util.Log
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

/**
 * The base class for all Activities in the NewsBlur app.  Handles enforcement of
 * login state and tracking of sync/update broadcasts.
 */
@AndroidEntryPoint
open class NbActivity : AppCompatActivity() {

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    @Inject
    lateinit var prefsRepo: PrefsRepo

    private var uniqueLoginKey: String? = null
    private var lastTheme: ThemeValue? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(this, "onCreate")

        val theme = prefsRepo.getSelectedTheme()
        applyTheme(theme)
        lastTheme = theme

        // in rare cases of process interruption or DB corruption, an activity can launch without valid
        // login creds.  redirect the user back to the loging workflow.
        if (prefsRepo.getUserId() == null) {
            Log.e(this, "post-login activity launched without valid login.")
            prefsRepo.logout(this, dbHelper)
            finish()
        }

        savedInstanceState?.let {
            uniqueLoginKey = it.getString(UNIQUE_LOGIN_KEY)
        }

        if (uniqueLoginKey == null) {
            uniqueLoginKey = prefsRepo.getUniqueLoginKey()
        }

        finishIfNotLoggedIn()

        // Facilitates the db updates by the sync service on the UI
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                launch {
                    NbSyncManager.state.collectLatest {
                        withContext(Dispatchers.Main) {
                            handleSyncUpdate(it)
                        }
                    }
                }
            }
        }
    }

    override fun onResume() {
        Log.d(this, "onResume" + UIUtils.getMemoryUsageDebug(this))
        super.onResume()
        finishIfNotLoggedIn()

        // is is possible that another activity changed the theme while we were on the backstack
        val currentSelectedTheme = prefsRepo.getSelectedTheme()
        if (lastTheme != currentSelectedTheme) {
            lastTheme = currentSelectedTheme
            UIUtils.restartActivity(this)
        }
    }

    override fun onPause() {
        Log.d(this.javaClass.name, "onPause")
        super.onPause()
    }

    private fun finishIfNotLoggedIn() {
        val currentLoginKey = prefsRepo.getUniqueLoginKey()
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

    private fun handleSyncUpdate(nbSync: NBSync) = when (nbSync) {
        is NBSync.Update -> handleUpdate(nbSync.type)
        is NBSync.Error -> handleErrorMsg(nbSync.msg)
    }

    protected open fun handleUpdate(updateType: Int) {
        Log.w(this, "activity doesn't implement handleUpdate")
    }

    private fun handleErrorMsg(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
    }
}

private const val UNIQUE_LOGIN_KEY = "uniqueLoginKey"