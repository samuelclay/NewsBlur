package com.newsblur.compose

import android.app.Dialog
import android.content.Context
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.os.bundleOf
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.fragment.app.DialogFragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.lifecycleScope
import com.newsblur.BuildConfig
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.design.NewsBlurTheme
import com.newsblur.design.toVariant
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.AppConstants
import com.newsblur.util.LanguageChooserRules
import com.newsblur.util.LanguageSettings
import com.newsblur.util.PrefConstants
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * LanguageChooserDialog.kt hosts LanguageChooser.kt once over the feed list. Main.java reports each feed list
 * load; the first one after a feed refresh in this app session decides whether to show it.
 */
@AndroidEntryPoint
class LanguageChooserDialog : DialogFragment() {
    @Inject
    lateinit var prefsRepo: PrefsRepo

    @Inject
    lateinit var userApi: UserApi

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setStyle(STYLE_NO_TITLE, 0)
    }

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog =
        super.onCreateDialog(savedInstanceState).apply {
            setCanceledOnTouchOutside(true)
            // TalkBack announces the window by this title; the dialog has no visible title bar.
            setTitle(R.string.language_title)
        }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View =
        ComposeView(requireContext()).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
            val detected = requireArguments().getString(ARG_LANGUAGE) ?: "en"
            setContent {
                val context = LocalContext.current
                NewsBlurTheme(variant = prefsRepo.getSelectedTheme().toVariant(), dynamic = false) {
                    val colors = LanguageChooserPalette.dialog(prefsRepo.getResolvedTheme(context))
                    val shape = RoundedCornerShape(16.dp)
                    var maxHeight by remember { mutableStateOf(availableHeight()) }
                    // A dialog restored after rotation is built before the activity lays out, so it measures again then.
                    DisposableEffect(Unit) {
                        val decor = requireActivity().window.decorView
                        val listener = View.OnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> maxHeight = availableHeight() }
                        decor.addOnLayoutChangeListener(listener)
                        onDispose { decor.removeOnLayoutChangeListener(listener) }
                    }
                    Box(Modifier.heightIn(max = maxHeight).clip(shape).background(colors.surface).border(1.dp, colors.outline, shape)) {
                        LanguageChooser(detected, colors, onKeep = ::dismissNow, onChoose = ::choose)
                    }
                }
            }
        }

    override fun onStart() {
        super.onStart()
        // A feed refresh can apply a language chosen on another device (SyncService.kt), recreating the activity
        // under a restored dialog. The account is no longer Automatic, so there is nothing left to ask.
        if (LanguageChooserGate.debugLanguage(requireContext()) == null && LanguageSettings.selected(requireContext()) != "auto") {
            dismissAllowingStateLoss()
            return
        }
        val window = dialog?.window ?: return
        // Phones get a full-width card with the halves stacked; wider windows get the side-by-side layout.
        val screen = resources.configuration.screenWidthDp
        val width = if (screen >= 600) min(screen - 48, 720) else screen - 32
        window.setLayout((width * resources.displayMetrics.density).roundToInt(), WindowManager.LayoutParams.WRAP_CONTENT)
        window.setBackgroundDrawable(ColorDrawable(android.graphics.Color.TRANSPARENT))
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(.45f)
    }

    // Leaves the scrim showing above and below a tall grid instead of letting the card meet the system bars.
    private fun availableHeight(): Dp {
        val decor = requireActivity().window.decorView
        val metrics = resources.displayMetrics
        val bars = ViewCompat.getRootWindowInsets(decor)?.getInsets(WindowInsetsCompat.Type.systemBars())
        if (decor.height == 0 || bars == null) return Dp.Infinity
        val available = decor.height - bars.top - bars.bottom
        return ((available / metrics.density).dp - 48.dp).coerceAtLeast(240.dp)
    }

    private fun choose(language: String) {
        val context = requireContext().applicationContext
        // Closed before the language applies, so the activity recreation it causes has no dialog to restore.
        dismissNow()
        LanguageChooserGate.save(context, userApi, language)
    }

    companion object {
        const val TAG = "language_chooser"
        const val ARG_LANGUAGE = "detected_language"
    }
}

object LanguageChooserGate {
    // Lets the feed list paint before the dialog rises over it.
    private const val SHOW_DELAY_MS = 600L

    // Decided at most once per app session.
    private var decided = false

    /** Main.java calls this whenever the feed list renders. */
    @JvmStatic
    fun feedListLoaded(activity: NbActivity) {
        if (decided || !ready(activity)) return
        decided = true
        val debug = debugLanguage(activity)
        val seen = activity.prefsRepo.getBoolean(PrefConstants.LANGUAGE_DIALOG_SEEN, false)
        when (LanguageChooserRules.gate(seen, LanguageSettings.selected(activity), debug)) {
            LanguageChooserRules.Gate.NONE -> Unit
            LanguageChooserRules.Gate.MARK_SEEN -> markSeen(activity)
            LanguageChooserRules.Gate.SHOW ->
                activity.window.decorView.postDelayed({
                    // Try again on a later feed list load if the screen went away in the meantime.
                    if (ready(activity)) show(activity, debug ?: detected(activity)) else decided = false
                }, SHOW_DELAY_MS)
        }
    }

    /**
     * The account language arrives with the feed list (SyncService.kt), so the dialog waits until a feed refresh
     * since login has finished. Until then, Automatic may only mean the account language hasn't loaded yet.
     */
    private fun ready(activity: NbActivity): Boolean =
        activity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) &&
            !activity.isFinishing &&
            !activity.supportFragmentManager.isStateSaved &&
            !activity.syncServiceState.isFeedFolderSyncRunning() &&
            activity.getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE).contains(AppConstants.LAST_SYNC_TIME)

    private fun show(
        activity: NbActivity,
        detected: String,
    ) {
        val fragments = activity.supportFragmentManager
        if (fragments.findFragmentByTag(LanguageChooserDialog.TAG) != null) return
        // Seen as soon as it shows: a dismissal, a choice, or the recreation a new language causes never brings it back.
        markSeen(activity)
        LanguageChooserDialog()
            .apply { arguments = bundleOf(LanguageChooserDialog.ARG_LANGUAGE to detected) }
            .show(fragments, LanguageChooserDialog.TAG)
    }

    private fun markSeen(context: Context) {
        context
            .getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(PrefConstants.LANGUAGE_DIALOG_SEEN, true)
            .apply()
    }

    /** The language Automatic resolved to, or the debug override. */
    fun detected(context: Context): String {
        debugLanguage(context)?.let { return it }
        val locales = context.resources.configuration.locales
        return LanguageChooserRules.detect((0 until locales.size()).map { locales[it] })
    }

    /**
     * Debug and alpha builds read a language code that forces the dialog on every app session, and the setup
     * language page, with that code as the detected language:
     * adb shell run-as com.newsblur.alpha, then add <string name="language_dialog_debug">de</string> to
     * shared_prefs/preferences.xml while the app is stopped.
     */
    fun debugLanguage(context: Context): String? {
        if (!BuildConfig.DEBUG) return null
        return context
            .getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)
            .getString(PrefConstants.LANGUAGE_DIALOG_DEBUG, null)
            ?.takeIf { it in LanguageSettings.names }
    }

    /**
     * SetupViewModel.kt asks whether first-run setup opens on the language page. Setup hosts the chooser itself,
     * so the standalone dialog is marked seen and never follows it. A language picked on the login screen is
     * already explicit and skips the page.
     */
    fun setupStep(
        context: Context,
        initialSetup: Boolean,
    ): Boolean {
        if (debugLanguage(context) != null) return true
        if (!initialSetup) return false
        markSeen(context)
        return LanguageSettings.selected(context) == "auto"
    }

    /**
     * Saves a language exactly like the Language row in SettingsFragment.kt: marked pending first, so a feed
     * refresh already in flight can't revert it, then sent to the account from a scope that outlives the
     * activity recreation the new language causes.
     */
    fun save(
        context: Context,
        userApi: UserApi,
        language: String,
    ) {
        val appContext = context.applicationContext
        LanguageSettings.select(appContext, language, pending = true)
        ProcessLifecycleOwner.get().lifecycleScope.launch {
            val saved = withContext(Dispatchers.IO) { userApi.setPreference("language", language) }
            if (!saved) {
                val message = LanguageSettings.localizedContext(appContext).getString(R.string.language_save_failed)
                Toast.makeText(appContext, message, Toast.LENGTH_LONG).show()
            }
        }
    }
}
