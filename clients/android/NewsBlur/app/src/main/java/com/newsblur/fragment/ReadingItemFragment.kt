package com.newsblur.fragment

import android.content.DialogInterface
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.text.TextUtils
import android.util.Log
import android.view.ContextMenu
import android.view.ContextMenu.ContextMenuInfo
import android.view.LayoutInflater
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView.HitTestResult
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.widget.PopupMenu
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.fragment.app.DialogFragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.material.button.MaterialButton
import com.google.android.material.chip.Chip
import com.newsblur.R
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.Reading
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.FragmentReadingitemBinding
import com.newsblur.databinding.ReadingItemActionsBinding
import com.newsblur.di.IconLoader
import com.newsblur.di.StoryImageCache
import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import com.newsblur.keyboard.KeyboardManager
import com.newsblur.network.APIConstants.NULL_STORY_TEXT
import com.newsblur.network.StoryApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.repository.StoryRepository
import com.newsblur.service.NbSyncManager.UPDATE_INTEL
import com.newsblur.service.NbSyncManager.UPDATE_SOCIAL
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.service.NbSyncManager.UPDATE_TEXT
import com.newsblur.util.DefaultFeedView
import com.newsblur.util.EdgeToEdgeUtil.applyNavBarInsetBottomTo
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.FileCache
import com.newsblur.util.Font
import com.newsblur.util.ImageLoader
import com.newsblur.util.MarkStoryReadBehavior
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.ReadingTextSize
import com.newsblur.util.StoryChangesState
import com.newsblur.util.StoryUtil
import com.newsblur.util.StoryUtils
import com.newsblur.util.UIUtils
import com.newsblur.util.executeAsyncTask
import com.newsblur.viewModel.ReadingItemViewModel
import com.newsblur.web.WebviewActionType
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.util.concurrent.atomic.AtomicBoolean
import java.util.regex.Pattern
import javax.inject.Inject
import kotlin.math.roundToInt

@AndroidEntryPoint
class ReadingItemFragment :
    NbFragment(),
    PopupMenu.OnMenuItemClickListener {
    @Inject
    lateinit var storyApi: StoryApi

    @Inject
    lateinit var dbHelper: BlurDatabaseHelper

    @Inject
    lateinit var feedUtils: FeedUtils

    @Inject
    lateinit var storyRepository: StoryRepository

    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    @Inject
    @StoryImageCache
    lateinit var storyImageCache: FileCache

    @Inject
    lateinit var prefsRepo: PrefsRepo

    @JvmField
    var story: Story? = null

    private var fs: FeedSet? = null
    private var feedColor: String? = null
    private var feedTitle: String? = null
    private var feedFade: String? = null
    private var feedBorder: String? = null
    private var feedIconUrl: String? = null
    private var faviconText: String? = null
    private var classifier: Classifier? = null
    private var displayFeedDetails = false
    private var userId: String? = null
    private var enableHighlights = false

    var selectedViewMode: DefaultFeedView = DefaultFeedView.STORY
        private set

    private var textViewUnavailable = false
    private var storyChangesState: StoryChangesState? = StoryChangesState.SHOW_CHANGES

    /** The story HTML, as provided by the 'content' element of the stories API.  */
    private var storyContent: String? = null

    /** The text-mode story HTML, as retrieved via the secondary original text API.  */
    private var originalText: String? = null
    private val imageAltTexts = mutableMapOf<String, String?>()
    private val imageUrlRemaps = mutableMapOf<String, String?>()
    private var sourceUserId: String? = null
    private var contentHash = 0
    private val storyHighlights = mutableSetOf<String>()

    // these three flags are progressively set by async callbacks and unioned
    // to set isLoadFinished, when we trigger any final UI tricks.
    private var isContentLoadFinished = false
    private var isSocialLoadFinished = false
    private val isWebLoadFinished = AtomicBoolean(false)
    private val isLoadFinished = AtomicBoolean(false)
    private var savedScrollPosRel = 0f
    private val webViewContentMutex = Any()

    private lateinit var binding: FragmentReadingitemBinding
    private lateinit var readingItemActionsBinding: ReadingItemActionsBinding

    private lateinit var markStoryReadBehavior: MarkStoryReadBehavior
    private var sampledQueue: SampledQueue? = null

    private lateinit var viewModel: ReadingItemViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = ViewModelProvider(this)[ReadingItemViewModel::class.java]

        story = requireArguments().getSerializable("story") as Story?

        displayFeedDetails = requireArguments().getBoolean("displayFeedDetails")
        feedIconUrl = requireArguments().getString("faviconUrl")
        feedTitle = requireArguments().getString("feedTitle")
        feedColor = requireArguments().getString("feedColor")
        feedFade = requireArguments().getString("feedFade")
        feedBorder = requireArguments().getString("feedBorder")
        faviconText = requireArguments().getString("faviconText")
        classifier = requireArguments().getSerializable("classifier") as Classifier?
        sourceUserId = requireArguments().getString("sourceUserId")

        userId = prefsRepo.getUserDetails().id
        enableHighlights = prefsRepo.getIsPremium() || prefsRepo.getIsArchive()
        markStoryReadBehavior = prefsRepo.getMarkStoryReadBehavior()

        if (markStoryReadBehavior == MarkStoryReadBehavior.IMMEDIATELY) {
            sampledQueue = SampledQueue(250, 5)
        }
        if (savedInstanceState != null) {
            savedScrollPosRel = savedInstanceState.getFloat(BUNDLE_SCROLL_POS_REL)
            // we can't actually use the saved scroll position until the webview finishes loading
        }

        story?.let { storyHighlights.addAll(it.highlights) }
    }

    override fun onSaveInstanceState(savedInstanceState: Bundle) {
        super.onSaveInstanceState(savedInstanceState)
        if (!::binding.isInitialized) return

        val heightm = binding.readingScrollview.getChildAt(0).measuredHeight
        val pos = binding.readingScrollview.scrollY
        savedInstanceState.putFloat(BUNDLE_SCROLL_POS_REL, pos.toFloat() / heightm)
    }

    override fun onDestroyView() {
        sampledQueue?.close()
        super.onDestroyView()
    }

    // WebViews don't automatically pause content like audio and video when they lose focus.  Chain our own
    // state into the webview so it behaves.
    override fun onPause() {
        binding.readingWebview.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        reloadStoryContent()
        binding.readingWebview.onResume()
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        binding = FragmentReadingitemBinding.inflate(inflater, container, false)
        readingItemActionsBinding = ReadingItemActionsBinding.bind(binding.root)

        val readingActivity = requireActivity() as Reading
        fs = readingActivity.fs

        selectedViewMode = prefsRepo.getDefaultViewModeForFeed(story!!.feedId)

        registerForContextMenu(binding.readingWebview)
        binding.readingWebview.setPrefsRepo(prefsRepo)
        binding.readingWebview.setCustomViewLayout(binding.customViewContainer)
        binding.readingWebview.setWebviewWrapperLayout(binding.readingContainer)
        binding.readingWebview.setBackgroundColor(Color.TRANSPARENT)
        binding.readingWebview.fragment = this
        binding.readingWebview.activity = readingActivity
        binding.readingWebview.setWebviewActionDelegate { action, selectedText ->
            handleWebviewAction(action, selectedText)
        }

        setupItemMetadata()
        updateTrainButton()
        updateShareButton()
        updateSaveButton()
        updateMarkStoryReadState()
        setupItemCommentsAndShares()

        binding.readingScrollview.registerScrollChangeListener(readingActivity)

        return binding.root
    }

    override fun onViewCreated(
        view: View,
        savedInstanceState: Bundle?,
    ) {
        super.onViewCreated(view, savedInstanceState)
        view.applyNavBarInsetBottomTo(readingItemActionsBinding.commentsContainer)

        binding.storyContextMenuButton.setOnClickListener { onClickMenuButton() }
        readingItemActionsBinding.markReadStoryButton.setOnClickListener { switchMarkStoryReadState() }
        readingItemActionsBinding.trainStoryButton.setOnClickListener { openStoryTrainer() }
        readingItemActionsBinding.saveStoryButton.setOnClickListener { switchStorySavedState() }
        readingItemActionsBinding.shareStoryButton.setOnClickListener { openShareDialog() }

        viewLifecycleOwner.lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.RESUMED) {
                launch {
                    viewModel.readingPayload.collect {
                        handleReadingItemState(it)
                    }
                }
                launch {
                    viewModel.storyHighlightsUpdate.collect {
                        handleStoryHighlightsUpdate(it)
                    }
                }
            }
        }
    }

    override fun onCreateContextMenu(
        menu: ContextMenu,
        v: View,
        menuInfo: ContextMenuInfo?,
    ) {
        val result = binding.readingWebview.hitTestResult
        if (result.type == HitTestResult.IMAGE_TYPE ||
            result.type == HitTestResult.SRC_IMAGE_ANCHOR_TYPE
        ) {
            // if the long-pressed item was an image, see if we can pop up a little dialogue
            // that presents the alt text.  Note that images wrapped in links tend to get detected
            // as anchors, not images, and may not point to the corresponding image URL.
            var imageURL = result.extra
            imageURL = imageURL!!.replace("file://", "")
            val mappedURL = imageUrlRemaps[imageURL]
            val finalURL: String = mappedURL ?: imageURL
            val altText = imageAltTexts[finalURL]
            val builder = AlertDialog.Builder(requireActivity())
            builder.setTitle(finalURL)
            if (altText != null) {
                builder.setMessage(UIUtils.fromHtml(altText))
            } else {
                builder.setMessage(finalURL)
            }
            var actionRID = R.string.alert_dialog_openlink
            if (result.type == HitTestResult.IMAGE_TYPE || result.type == HitTestResult.SRC_IMAGE_ANCHOR_TYPE) {
                actionRID = R.string.alert_dialog_openimage
            }
            builder.setPositiveButton(
                actionRID,
                object : DialogInterface.OnClickListener {
                    override fun onClick(
                        dialog: DialogInterface,
                        id: Int,
                    ) {
                        val i = Intent(Intent.ACTION_VIEW)
                        i.data = Uri.parse(finalURL)
                        try {
                            startActivity(i)
                        } catch (e: Exception) {
                            Log.wtf(this.javaClass.name, "device cannot open URLs")
                        }
                    }
                },
            )
            builder.setNegativeButton(R.string.alert_dialog_done) { _, _ ->
                // do nothing
            }
            builder.show()
        } else if (result.type == HitTestResult.SRC_ANCHOR_TYPE) {
            val url = result.extra
            val intent = Intent(Intent.ACTION_SEND)
            intent.type = "text/plain"
            intent.putExtra(Intent.EXTRA_SUBJECT, UIUtils.fromHtml(story!!.title).toString())
            intent.putExtra(Intent.EXTRA_TEXT, url)
            startActivity(Intent.createChooser(intent, "Share using"))
        } else {
            super.onCreateContextMenu(menu, v, menuInfo)
        }
    }

    private fun handleReadingItemState(readingPayload: ReadingItemViewModel.ReadingPayload) {
        when (readingPayload) {
            ReadingItemViewModel.Idle -> {}
            ReadingItemViewModel.NoStoryContent -> {
                com.newsblur.util.Log
                    .w(this, "Couldn't find story content for existing story.")
                activity?.finish()
            }

            is ReadingItemViewModel.StoryContent -> {
                storyContent = readingPayload.content
            }

            is ReadingItemViewModel.StoryOriginalText -> {
                if (readingPayload.text == NULL_STORY_TEXT) {
                    textViewUnavailable = true
                } else {
                    originalText = readingPayload.text
                }
            }
        }
        reloadStoryContent()
    }

    private fun handleStoryHighlightsUpdate(highlights: List<String>) {
        story?.let {
            if (storyHighlights == highlights) return@let
            storyHighlights.clear()
            storyHighlights.addAll(highlights)

            applyStoryHighlights()
        }
    }

    private fun onClickMenuButton() {
        val pm = PopupMenu(requireActivity(), binding.storyContextMenuButton)
        val menu = pm.menu
        pm.menuInflater.inflate(R.menu.story_context, menu)

        menu.findItem(R.id.menu_reading_save).setTitle(if (story!!.starred) R.string.menu_unsave_story else R.string.menu_save_story)
        if (fs!!.isFilterSaved ||
            fs!!.isAllSaved ||
            fs!!.singleSavedTag != null
        ) {
            menu.findItem(R.id.menu_reading_markunread).isVisible = false
        }

        if (KeyboardManager.hasHardwareKeyboard(requireContext())) {
            menu.findItem(R.id.menu_shortcuts).isVisible = true
        }

        when (prefsRepo.getSelectedTheme()) {
            ThemeValue.LIGHT -> menu.findItem(R.id.menu_theme_light).isChecked = true
            ThemeValue.DARK -> menu.findItem(R.id.menu_theme_dark).isChecked = true
            ThemeValue.BLACK -> menu.findItem(R.id.menu_theme_black).isChecked = true
            ThemeValue.AUTO -> menu.findItem(R.id.menu_theme_auto).isChecked = true
        }

        val readingTextSize = prefsRepo.getReadingTextSize()
        when (ReadingTextSize.fromSize(readingTextSize)) {
            ReadingTextSize.XS -> menu.findItem(R.id.menu_text_size_xs).isChecked = true
            ReadingTextSize.S -> menu.findItem(R.id.menu_text_size_s).isChecked = true
            ReadingTextSize.M -> menu.findItem(R.id.menu_text_size_m).isChecked = true
            ReadingTextSize.L -> menu.findItem(R.id.menu_text_size_l).isChecked = true
            ReadingTextSize.XL -> menu.findItem(R.id.menu_text_size_xl).isChecked = true
            ReadingTextSize.XXL -> menu.findItem(R.id.menu_text_size_xxl).isChecked = true
        }

        when (Font.getFont(prefsRepo.getFontString())) {
            Font.ANONYMOUS_PRO -> menu.findItem(R.id.menu_font_anonymous).isChecked = true
            Font.CHRONICLE -> menu.findItem(R.id.menu_font_chronicle).isChecked = true
            Font.DEFAULT -> menu.findItem(R.id.menu_font_default).isChecked = true
            Font.GOTHAM_NARROW -> menu.findItem(R.id.menu_font_gotham).isChecked = true
            Font.NOTO_SANS -> menu.findItem(R.id.menu_font_noto_sand).isChecked = true
            Font.NOTO_SERIF -> menu.findItem(R.id.menu_font_noto_serif).isChecked = true
            Font.OPEN_SANS_CONDENSED -> menu.findItem(R.id.menu_font_open_sans).isChecked = true
            Font.ROBOTO -> menu.findItem(R.id.menu_font_roboto).isChecked = true
        }

        pm.setOnMenuItemClickListener(this)
        pm.show()
    }

    override fun onMenuItemClick(item: MenuItem): Boolean =
        when (item.itemId) {
            R.id.menu_reading_original -> {
                openBrowser()
                true
            }

            R.id.menu_reading_sharenewsblur -> {
                var sourceUserId: String? = null
                if (fs!!.singleSocialFeed != null) sourceUserId = fs!!.singleSocialFeed.key
                val newFragment: DialogFragment = ShareDialogFragment.newInstance(story, sourceUserId)
                newFragment.show(requireActivity().supportFragmentManager, "dialog")
                true
            }

            R.id.menu_send_story -> {
                feedUtils.sendStoryUrl(story, requireContext())
                true
            }

            R.id.menu_send_story_full -> {
                feedUtils.sendStoryFull(story, requireContext())
                true
            }

            R.id.menu_shortcuts -> {
                showStoryShortcuts()
                true
            }

            R.id.menu_text_size_xs -> {
                setTextSizeStyle(ReadingTextSize.XS)
                true
            }

            R.id.menu_text_size_s -> {
                setTextSizeStyle(ReadingTextSize.S)
                true
            }

            R.id.menu_text_size_m -> {
                setTextSizeStyle(ReadingTextSize.M)
                true
            }

            R.id.menu_text_size_l -> {
                setTextSizeStyle(ReadingTextSize.L)
                true
            }

            R.id.menu_text_size_xl -> {
                setTextSizeStyle(ReadingTextSize.XL)
                true
            }

            R.id.menu_text_size_xxl -> {
                setTextSizeStyle(ReadingTextSize.XXL)
                true
            }

            R.id.menu_font_anonymous -> {
                setReadingFont(getString(R.string.anonymous_pro_font_prefvalue))
                true
            }

            R.id.menu_font_chronicle -> {
                setReadingFont(getString(R.string.chronicle_font_prefvalue))
                true
            }

            R.id.menu_font_default -> {
                setReadingFont(getString(R.string.default_font_prefvalue))
                true
            }

            R.id.menu_font_gotham -> {
                setReadingFont(getString(R.string.gotham_narrow_font_prefvalue))
                true
            }

            R.id.menu_font_noto_sand -> {
                setReadingFont(getString(R.string.noto_sans_font_prefvalue))
                true
            }

            R.id.menu_font_noto_serif -> {
                setReadingFont(getString(R.string.noto_serif_font_prefvalue))
                true
            }

            R.id.menu_font_open_sans -> {
                setReadingFont(getString(R.string.open_sans_condensed_font_prefvalue))
                true
            }

            R.id.menu_font_roboto -> {
                setReadingFont(getString(R.string.roboto_font_prefvalue))
                true
            }

            R.id.menu_reading_save -> {
                if (story!!.starred) {
                    feedUtils.setStorySaved(story!!, false, requireContext(), emptyList(), emptyList())
                } else {
                    feedUtils.setStorySaved(story!!.storyHash, true, requireContext(), emptyList())
                }
                true
            }

            R.id.menu_reading_markunread -> {
                feedUtils.markStoryUnread(story!!, requireContext())
                true
            }

            R.id.menu_theme_auto -> {
                prefsRepo.setSelectedTheme(ThemeValue.AUTO)
                UIUtils.restartActivity(requireActivity())
                true
            }

            R.id.menu_theme_light -> {
                prefsRepo.setSelectedTheme(ThemeValue.LIGHT)
                UIUtils.restartActivity(requireActivity())
                true
            }

            R.id.menu_theme_dark -> {
                prefsRepo.setSelectedTheme(ThemeValue.DARK)
                UIUtils.restartActivity(requireActivity())
                true
            }

            R.id.menu_theme_black -> {
                prefsRepo.setSelectedTheme(ThemeValue.BLACK)
                UIUtils.restartActivity(requireActivity())
                true
            }

            R.id.menu_intel -> {
                // check against training on feedless stories
                if (story!!.feedId != "0") {
                    openStoryTrainer()
                }
                true
            }

            R.id.menu_go_to_feed -> {
                val feed = dbHelper.getFeed(story!!.feedId)
                feed?.let {
                    val fs = FeedSet.singleFeed(it.feedId)
                    FeedItemsList.startActivity(requireContext(), fs, it, null, null)
                }
                true
            }

            else -> {
                super.onOptionsItemSelected(item)
            }
        }

    fun switchMarkStoryReadState(notifyUser: Boolean = false) {
        story?.let {
            val msg =
                if (it.read) {
                    feedUtils.markStoryUnread(it, requireContext())
                    getString(R.string.story_unread)
                } else {
                    feedUtils.markStoryAsRead(it, requireContext())
                    getString(R.string.story_read)
                }
            if (notifyUser) UIUtils.showSnackBar(binding.root, msg)
        } ?: Log.e(this.javaClass.name, "Error switching null story read state.")
    }

    private fun updateMarkStoryReadState() {
        if (markStoryReadBehavior == MarkStoryReadBehavior.MANUALLY) {
            readingItemActionsBinding.markReadStoryButton.visibility = View.VISIBLE
            readingItemActionsBinding.markReadStoryButton.setStoryReadState(prefsRepo, story!!.read)
        } else {
            readingItemActionsBinding.markReadStoryButton.visibility = View.GONE
        }

        sampledQueue?.add { updateStoryReadTitleState.invoke() }
            ?: updateStoryReadTitleState.invoke()
    }

    fun openStoryTrainer() {
        val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
        intelFrag.show(requireActivity().supportFragmentManager, StoryIntelTrainerFragment::class.java.name)
    }

    private fun updateTrainButton() {
        readingItemActionsBinding.trainStoryButton.visibility = if (story!!.feedId == "0") View.GONE else View.VISIBLE
    }

    fun switchStorySavedState(notifyUser: Boolean = false) {
        story?.let {
            val msg =
                if (it.starred) {
                    feedUtils.setStorySaved(it.storyHash, false, requireContext(), emptyList()) // TODO
                    getString(R.string.story_saved)
                } else {
                    feedUtils.setStorySaved(it.storyHash, true, requireContext(), emptyList()) // TODO
                    getString(R.string.story_unsaved)
                }
            if (notifyUser) UIUtils.showSnackBar(binding.root, msg)
        } ?: Log.e(this.javaClass.name, "Error switching null story saved state.")
    }

    private fun updateSaveButton() {
        readingItemActionsBinding.saveStoryButton.setText(if (story!!.starred) R.string.unsave_this else R.string.save_this)
    }

    fun openShareDialog() {
        val newFragment: DialogFragment = ShareDialogFragment.newInstance(story, sourceUserId)
        newFragment.show(parentFragmentManager, "dialog")
    }

    private fun updateShareButton() {
        for (userId in story!!.sharedUserIds) {
            if (userId == this@ReadingItemFragment.userId!!) {
                readingItemActionsBinding.shareStoryButton.setText(R.string.already_shared)
                return
            }
        }
        readingItemActionsBinding.shareStoryButton.setText(R.string.share_this)
    }

    private fun setupItemCommentsAndShares() {
        SetupCommentSectionTask(this, binding.root, layoutInflater, story, iconLoader).execute()
    }

    private fun setupItemMetadata() {
        if (feedColor == null || feedFade == null || feedColor == "null" || feedFade == "null") {
            feedColor = "303030"
            feedFade = "505050"
            feedBorder = "202020"
        }
        val colors = intArrayOf(Color.parseColor("#$feedColor"), Color.parseColor("#$feedFade"))
        val gradient = GradientDrawable(GradientDrawable.Orientation.BOTTOM_TOP, colors)
        UIUtils.setViewBackground(binding.rowItemFeedHeader, gradient)

        if (faviconText == "black") {
            binding.readingFeedTitle.setTextColor(ContextCompat.getColor(requireContext(), R.color.text))
            binding.readingFeedTitle.setShadowLayer(1f, 0f, 1f, ContextCompat.getColor(requireContext(), R.color.half_white))
        } else {
            binding.readingFeedTitle.setTextColor(ContextCompat.getColor(requireContext(), R.color.white))
            binding.readingFeedTitle.setShadowLayer(1f, 0f, 1f, ContextCompat.getColor(requireContext(), R.color.half_black))
        }
        if (!displayFeedDetails) {
            binding.readingFeedTitle.visibility = View.GONE
            binding.readingFeedIcon.visibility = View.GONE
        } else {
            iconLoader.displayImage(feedIconUrl, binding.readingFeedIcon)
            binding.readingFeedTitle.text = feedTitle
        }

        binding.readingItemDate.text = StoryUtils.formatLongDate(requireContext(), story!!.timestamp)

        if (story!!.tags.isEmpty()) {
            binding.readingItemTags.visibility = View.GONE
        }

        if (selectedViewMode == DefaultFeedView.STORY && story!!.hasModifications) {
            binding.readingStoryChanges.visibility = View.VISIBLE
            binding.readingStoryChanges.setOnClickListener { loadStoryChanges() }
        }

        if (story!!.starred && story!!.starredTimestamp != 0L) {
            val savedTimestampText =
                String.format(
                    resources.getString(R.string.story_saved_timestamp),
                    StoryUtils.formatLongDate(activity, story!!.starredTimestamp),
                )
            binding.readingItemSavedTimestamp.text = savedTimestampText
            binding.readingItemSavedTimestamp.visibility = View.VISIBLE
        } else {
            binding.readingItemSavedTimestamp.visibility = View.GONE
        }

        binding.readingItemAuthors.setOnClickListener(
            View.OnClickListener {
                if (story!!.feedId == "0") return@OnClickListener // cannot train on feedless stories
                val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
                intelFrag.show(parentFragmentManager, StoryIntelTrainerFragment::class.java.name)
            },
        )
        binding.readingFeedTitle.setOnClickListener(
            View.OnClickListener {
                if (story!!.feedId == "0") return@OnClickListener // cannot train on feedless stories
                val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
                intelFrag.show(parentFragmentManager, StoryIntelTrainerFragment::class.java.name)
            },
        )
        binding.readingItemTitle.setOnClickListener { openBrowser() }

        setupTagsAndIntel()
    }

    private fun setupTagsAndIntel() {
        binding.readingItemTags.removeAllViews()
        for (tag in story!!.tags) {
            val v = layoutInflater.inflate(R.layout.chip_view, null)

            val chip: Chip = v.findViewById(R.id.chip)
            chip.text = tag

            if (classifier != null && classifier!!.tags.containsKey(tag)) {
                when (classifier!!.tags[tag]) {
                    Classifier.LIKE -> {
                        chip.setChipBackgroundColorResource(R.color.tag_green)
                        chip.setTextColor(ContextCompat.getColor(requireContext(), R.color.tag_green_text))
                        chip.chipIcon = ContextCompat.getDrawable(requireContext(), R.drawable.ic_thumb_up_green)
                    }

                    Classifier.DISLIKE -> {
                        chip.setChipBackgroundColorResource(R.color.tag_red)
                        chip.setTextColor(ContextCompat.getColor(requireContext(), R.color.tag_red_text))
                        chip.chipIcon = ContextCompat.getDrawable(requireContext(), R.drawable.ic_thumb_down_red)
                    }
                }
            }

            // tapping tags in saved stories doesn't bring up training
            if (!(fs!!.isAllSaved || fs!!.singleSavedTag != null)) {
                v.setOnClickListener {
                    if (story!!.feedId == "0") return@setOnClickListener // cannot train on feedless stories
                    val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
                    intelFrag.show(parentFragmentManager, StoryIntelTrainerFragment::class.java.name)
                }
            }

            binding.readingItemTags.addView(v)
        }

        setupUserTags()

        if (!TextUtils.isEmpty(story!!.authors)) {
            binding.readingItemAuthors.text = "•   " + story!!.authors
            if (classifier != null && classifier!!.authors.containsKey(story!!.authors)) {
                when (classifier!!.authors[story!!.authors]) {
                    Classifier.LIKE -> binding.readingItemAuthors.setTextColor(ContextCompat.getColor(requireContext(), R.color.positive))
                    Classifier.DISLIKE ->
                        binding.readingItemAuthors.setTextColor(
                            ContextCompat.getColor(requireContext(), R.color.negative),
                        )

                    else ->
                        binding.readingItemAuthors.setTextColor(
                            UIUtils.getThemedColor(requireContext(), R.attr.readingItemMetadata, android.R.attr.textColor),
                        )
                }
            }
        }

        var title = story!!.title
        title = UIUtils.colourTitleFromClassifier(title, classifier)
        binding.readingItemTitle.text = UIUtils.fromHtml(title)
    }

    private fun setupUserTags() {
        binding.readingItemUserTags.removeAllViews()

        if (story?.userTags?.isNotEmpty() == true) {
            for (tag in story!!.userTags) {
                val chipView = createTagChip(tag, story!!, fs!!)
                binding.readingItemUserTags.addView(chipView)
            }
            val addTagView = createTagChip(getString(R.string.add_tag), story!!, fs!!)
            binding.readingItemUserTags.addView(addTagView)
        } else if (story?.starred == true) {
            val addTagView = createTagChip(getString(R.string.add_tag), story!!, fs!!)
            binding.readingItemUserTags.addView(addTagView)
        }

        binding.readingItemUserTags.visibility = View.VISIBLE
    }

    private fun createTagChip(
        tag: String,
        story: Story,
        feedSet: FeedSet,
    ): View {
        val v = layoutInflater.inflate(R.layout.chip_view, null)
        val chip: Chip = v.findViewById(R.id.chip)
        chip.text = tag
        chip.chipIcon = ContextCompat.getDrawable(requireContext(), R.drawable.ic_tag)
        v.setOnClickListener {
            showUserTagsFragment(story, feedSet)
        }
        return v
    }

    private fun showUserTagsFragment(
        story: Story,
        feedSet: FeedSet,
    ) {
        val userTagsFragment = StoryUserTagsFragment.newInstance(story, feedSet)
        userTagsFragment.show(childFragmentManager, StoryUserTagsFragment::class.java.name)
    }

    fun switchSelectedViewMode() {
        // if we were already in text mode, switch back to story mode
        if (selectedViewMode == DefaultFeedView.TEXT) {
            setViewMode(DefaultFeedView.STORY)
        } else {
            setViewMode(DefaultFeedView.TEXT)
        }

        (requireActivity() as Reading).viewModeChanged()
        // telling the activity to change modes will chain a call to viewModeChanged()
    }

    private fun setViewMode(newMode: DefaultFeedView) {
        selectedViewMode = newMode
        prefsRepo.setDefaultViewModeForFeed(story!!.feedId, newMode)
    }

    fun viewModeChanged() {
        synchronized(selectedViewMode) {
            selectedViewMode = prefsRepo.getDefaultViewModeForFeed(story!!.feedId)
        }
        // these can come from async tasks
        activity?.runOnUiThread { reloadStoryContent() }
    }

    private fun reloadStoryContent() {
        // reset indicators
        binding.readingTextloading.visibility = View.GONE
        binding.readingTextmodefailed.visibility = View.GONE
        enableProgress(false)

        var needStoryContent = false
        var enableStoryChanges = false

        if (selectedViewMode == DefaultFeedView.STORY) {
            needStoryContent = true
            enableStoryChanges = story != null && story!!.hasModifications
        } else {
            when {
                textViewUnavailable -> {
                    binding.readingTextmodefailed.visibility = View.VISIBLE
                    needStoryContent = true
                }

                originalText == null -> {
                    binding.readingTextloading.visibility = View.VISIBLE
                    enableProgress(true)
                    story?.let { viewModel.loadOriginalText(it.storyHash) } ?: activity?.finish()
                    // still show the story mode version, as the text mode one may take some time
                    needStoryContent = true
                }

                else -> {
                    setupWebview(originalText!!) // TODO extract images
                    onContentLoadFinished()
                }
            }
        }

        if (needStoryContent) {
            if (storyContent == null) {
                story?.let { viewModel.loadStoryContent(it.storyHash) } ?: activity?.finish()
            } else {
                setupWebview(storyContent!!) // TODO extract images
                onContentLoadFinished()
            }
        }

        binding.readingStoryChanges.visibility = if (enableStoryChanges) View.VISIBLE else View.GONE
    }

    private fun enableProgress(loading: Boolean) {
        (activity as Reading?)?.enableLeftProgressCircle(loading)
    }

    /**
     * Lets the pager offer us an updated version of our story when a new cursor is
     * cycled in. This class takes the responsibility of ensureing that the cursor
     * index has not shifted, though, by checking story IDs.
     */
    fun offerStoryUpdate(story: Story?) {
        if (story == null) return
        if (story.storyHash != this.story!!.storyHash) {
            com.newsblur.util.Log
                .d(this, "prevented story list index offset shift")
            return
        }
        this.story = story
        // if (AppConstants.VERBOSE_LOG) com.newsblur.util.Log.d(this, "got fresh story");
    }

    fun handleUpdate(updateType: Int) {
        if (updateType and UPDATE_STORY != 0) {
            updateSaveButton()
            updateShareButton()
            updateMarkStoryReadState()
            setupItemCommentsAndShares()
            setupItemMetadata()
        }
        if (updateType and UPDATE_TEXT != 0) {
            reloadStoryContent()
        }
        if (updateType and UPDATE_SOCIAL != 0) {
            updateShareButton()
            setupItemCommentsAndShares()
        }
        if (updateType and UPDATE_INTEL != 0) {
            classifier = dbHelper.getClassifierForFeed(story!!.feedId)
            setupTagsAndIntel()
        }
    }

    private fun loadStoryChanges() {
        val showChanges = storyChangesState == null || storyChangesState === StoryChangesState.SHOW_CHANGES
        story?.let { story ->
            lifecycleScope.executeAsyncTask(
                onPreExecute = {
                    binding.readingStoryChanges.setText(R.string.story_changes_loading)
                },
                doInBackground = {
                    storyApi.getStoryChanges(story.storyHash, showChanges)
                },
                onPostExecute = { response ->
                    if (response != null && !response.isError && response.story != null) {
                        storyContent = response.story.content
                        reloadStoryContent()
                        binding.readingStoryChanges.setText(
                            if (showChanges) R.string.story_hide_changes else R.string.story_show_changes,
                        )
                        storyChangesState = if (showChanges) StoryChangesState.HIDE_CHANGES else StoryChangesState.SHOW_CHANGES
                    } else {
                        binding.readingStoryChanges.setText(
                            if (showChanges) R.string.story_show_changes else R.string.story_hide_changes,
                        )
                    }
                },
            )
        }
    }

    private fun setupWebview(content: String) {
        // sometimes we get called before the activity is ready. abort, since we will get a refresh when
        // the cursor loads
        activity?.let {
            it.runOnUiThread { setupWebviewInternal(content, storyHighlights) }
        }
    }

    private fun setupWebviewInternal(
        content: String,
        highlights: Set<String>,
    ) {
        if (activity == null) {
            // this method gets called by async UI bits that might hold stale fragment references with no assigned
            // activity.  If this happens, just abort the call.
            return
        }
        val size = prefsRepo.getReadingTextSize()
        val fontCss = prefsRepo.getFont().forWebView(size)
        val theme = prefsRepo.getSelectedTheme()
        val nightMask = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK

        viewLifecycleOwner.lifecycleScope.launch {
            sniffAltTexts(content)
            val html =
                StoryUtil.buildMinimalHtml(
                    storyHtml = swapInOfflineImages(content),
                    fontCss = fontCss,
                    themeValue = theme,
                    nightMask = nightMask,
                    enableHighlights = enableHighlights,
                )
            val newHash = (html to highlights).hashCode()
            synchronized(webViewContentMutex) {
                // this method might get called repeatedly despite no content change, which is expensive
                if (this@ReadingItemFragment.contentHash == newHash) return@synchronized
                this@ReadingItemFragment.contentHash = newHash

                isWebLoadFinished.set(false)
                binding.readingWebview.loadDataWithBaseURL("file:///android_asset/", html, "text/html", "UTF-8", null)
                onContentLoadFinished()
            }
        }
    }

    private fun applyStoryHighlights() {
        if (!enableHighlights) return
        val json = JSONArray(storyHighlights).toString()
        binding.readingWebview.evaluateJavascript("NB_applyHighlights($json);", null)
    }

    private suspend fun sniffAltTexts(html: String) =
        withContext(Dispatchers.Default) {
            // Find images with alt tags and cache the text for use on long-press
            //   NOTE: if doing this via regex has a smell, you have a good nose!  This method is far from perfect
            //   and may miss valid cases or trucate tags, but it works for popular feeds (read: XKCD) and doesn't
            //   require us to import a proper parser lib of hundreds of kilobytes just for this one feature.
            imageAltTexts.clear()
            // sniff for alts first
            var imgTagMatcher = altSniff1.matcher(html)
            while (imgTagMatcher.find()) {
                imageAltTexts[imgTagMatcher.group(2)] = imgTagMatcher.group(4)
            }
            imgTagMatcher = altSniff2.matcher(html)
            while (imgTagMatcher.find()) {
                imageAltTexts[imgTagMatcher.group(4)] = imgTagMatcher.group(2)
            }
            // then sniff for 'title' tags, so they will overwrite alts and take precedence
            imgTagMatcher = altSniff3.matcher(html)
            while (imgTagMatcher.find()) {
                imageAltTexts[imgTagMatcher.group(2)] = imgTagMatcher.group(4)
            }
            imgTagMatcher = altSniff4.matcher(html)
            while (imgTagMatcher.find()) {
                imageAltTexts[imgTagMatcher.group(4)] = imgTagMatcher.group(2)
            }

            // while were are at it, create a place where we can later cache offline image remaps so that when
            // we do an alt-text lookup, we can search for the right URL key.
            imageUrlRemaps.clear()
        }

    private fun swapInOfflineImages(htmlString: String): String {
        var html = htmlString
        val imageTagMatcher = imgSniff.matcher(html)
        while (imageTagMatcher.find()) {
            val url = imageTagMatcher.group(2)
            val localPath = storyImageCache.getCachedLocation(url) ?: continue
            html = html.replace(imageTagMatcher.group(1) + "\"" + url + "\"", "src=\"$localPath\"")
            imageUrlRemaps[localPath] = url
        }

        return html
    }

    /** We have pushed our desired content into the WebView.  */
    private fun onContentLoadFinished() {
        isContentLoadFinished = true
        checkLoadStatus()
    }

    /** The webview has finished loading our desired content.  */
    fun onWebLoadFinished() {
        if (!isWebLoadFinished.getAndSet(true)) {
            binding.readingWebview.evaluateJavascript("loadImages();", null)
        }
        checkLoadStatus()
    }

    /** The social UI has finished loading from the DB.  */
    fun onSocialLoadFinished() {
        isSocialLoadFinished = true
        checkLoadStatus()
    }

    private fun checkLoadStatus() {
        synchronized(isLoadFinished) {
            if (isContentLoadFinished && isWebLoadFinished.get() && isSocialLoadFinished) {
                // iff this is the first time all content has finished loading, trigger any UI
                // behaviour that is position-dependent
                if (!isLoadFinished.getAndSet(true)) {
                    onLoadFinished()
                }

                applyStoryHighlights()
            }
        }
    }

    /**
     * A hook for performing actions that need to happen after all of the view has loaded, including
     * the story's HTML content, all metadata views, and all associated social views.
     */
    private fun onLoadFinished() {
        // if there was a scroll position saved, restore it
        if (savedScrollPosRel > 0f) {
            // ScrollViews containing WebViews are very particular about call timing.  since the inner view
            // height can drastically change as viewport width changes, position has to be saved and restored
            // as a proportion of total inner view height. that height won't be known until all the various
            // async bits of the fragment have finished loading.  however, even after the WebView calls back
            // onProgressChanged with a value of 100, immediate calls to get the size of the view will return
            // incorrect values.  even posting a runnable to the very end of our UI event queue may be
            // insufficient time to allow the WebView to actually finish internally computing state and size.
            // an additional fixed delay is added in a last ditch attempt to give the black-box platform
            // threads a chance to finish their work.
            binding.readingScrollview.postDelayed({
                val relPos = (binding.readingScrollview.getChildAt(0).measuredHeight * savedScrollPosRel).roundToInt()
                binding.readingScrollview.scrollTo(0, relPos)
            }, 75L)
        }
    }

    fun showStoryShortcuts() {
        val newFragment = StoryShortcutsFragment()
        newFragment.show(requireActivity().supportFragmentManager, StoryShortcutsFragment::class.java.name)
    }

    private val updateStoryReadTitleState = {
        story?.let {
            val (typeFace, iconVisibility) =
                if (it.read) {
                    Typeface.create(binding.readingItemTitle.typeface, Typeface.NORMAL) to View.GONE
                } else {
                    Typeface.create(binding.readingItemTitle.typeface, Typeface.BOLD) to View.VISIBLE
                }
            binding.readingItemTitle.typeface = typeFace
            binding.readingItemUnreadIcon.visibility = iconVisibility
        }
    }

    private fun setTextSizeStyle(readingTextSize: ReadingTextSize) {
        val textSize = readingTextSize.size
        prefsRepo.setReadingTextSize(textSize)
        binding.readingWebview.setTextSize(textSize)
    }

    private fun setReadingFont(font: String) {
        prefsRepo.setFontString(font)
        contentHash = 0 // Force reload since content hasn't changed
        reloadStoryContent()
    }

    fun openBrowser() {
        story?.let {
            val uri = Uri.parse(it.permalink)
            UIUtils.handleUri(requireContext(), prefsRepo, uri)
        } ?: Log.e(this.javaClass.name, "Error opening null story by permalink URL.")
    }

    fun scrollToComments() {
        val targetView =
            if (readingItemActionsBinding.readingFriendCommentHeader.isVisible) {
                readingItemActionsBinding.readingFriendCommentContainer
            } else if (readingItemActionsBinding.readingPublicCommentHeader.isVisible) {
                readingItemActionsBinding.readingPublicCommentContainer
            } else {
                null
            }
        targetView?.let {
            it.parent.requestChildFocus(targetView, it)
        }
    }

    fun scrollVerticallyBy(dy: Int) {
        binding.readingScrollview.smoothScrollBy(0, dy)
    }

    /**
     * Determines whether the fragment should receive an update for story original text content.
     * This ensures that only fragments that actually need the update will process it,
     * preventing unnecessary reprocessing.
     */
    fun shouldReceiveUpdateText(updateType: Int) = updateType and UPDATE_TEXT != 0 && originalText == null

    private fun handleWebviewAction(
        actionType: WebviewActionType,
        selectedText: String,
    ) {
        when (actionType) {
            WebviewActionType.WEB_SEARCH -> {
                if (selectedText.isNotEmpty()) {
                    UIUtils.openWebSearch(requireContext(), selectedText)
                }
            }

            WebviewActionType.HIGHLIGHT -> {
                story?.let {
                    viewModel.updateHighlights(selectedText, it.storyHash, storyHighlights)
                }
            }
        }
    }

    companion object {
        private const val BUNDLE_SCROLL_POS_REL = "scrollStateRel"
        const val VERTICAL_SCROLL_DISTANCE_DP = 240

        @JvmStatic
        fun newInstance(
            story: Story?,
            feedTitle: String?,
            feedFaviconColor: String?,
            feedFaviconFade: String?,
            feedFaviconBorder: String?,
            faviconText: String?,
            faviconUrl: String?,
            classifier: Classifier?,
            displayFeedDetails: Boolean,
            sourceUserId: String?,
        ): ReadingItemFragment {
            val readingFragment = ReadingItemFragment()

            val args = Bundle()
            args.putSerializable("story", story)
            args.putString("feedTitle", feedTitle)
            args.putString("feedColor", feedFaviconColor)
            args.putString("feedFade", feedFaviconFade)
            args.putString("feedBorder", feedFaviconBorder)
            args.putString("faviconText", faviconText)
            args.putString("faviconUrl", faviconUrl)
            args.putBoolean("displayFeedDetails", displayFeedDetails)
            args.putSerializable("classifier", classifier)
            args.putString("sourceUserId", sourceUserId)
            readingFragment.arguments = args

            return readingFragment
        }

        private val altSniff1 =
            Pattern.compile(
                "<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*alt=(['\"])((?:(?!\\3).)*)\\3[^>]*>",
                Pattern.CASE_INSENSITIVE,
            )
        private val altSniff2 =
            Pattern.compile(
                "<img[^>]*alt=(['\"])((?:(?!\\1).)*)\\1[^>]*src=(['\"])((?:(?!\\3).)*)\\3[^>]*>",
                Pattern.CASE_INSENSITIVE,
            )
        private val altSniff3 =
            Pattern.compile(
                "<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*title=(['\"])((?:(?!\\3).)*)\\3[^>]*>",
                Pattern.CASE_INSENSITIVE,
            )
        private val altSniff4 =
            Pattern.compile(
                "<img[^>]*title=(['\"])((?:(?!\\1).)*)\\1[^>]*src=(['\"])((?:(?!\\3).)*)\\3[^>]*>",
                Pattern.CASE_INSENSITIVE,
            )
        private val imgSniff = Pattern.compile("<img[^>]*(src\\s*=\\s*)\"([^\"]*)\"[^>]*>", Pattern.CASE_INSENSITIVE)
    }
}

private fun MaterialButton.setStoryReadState(
    prefsRepo: PrefsRepo,
    isRead: Boolean,
) {
    var selectedTheme = prefsRepo.getSelectedTheme()
    if (selectedTheme == ThemeValue.AUTO) {
        selectedTheme =
            when (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) {
                Configuration.UI_MODE_NIGHT_YES -> ThemeValue.DARK
                else -> ThemeValue.LIGHT
            }
    }
    val styleResId: Int =
        when (selectedTheme) {
            ThemeValue.LIGHT -> if (isRead) R.style.storyButtonsDimmed else R.style.storyButtons
            else -> if (isRead) R.style.storyButtonsDimmed_dark else R.style.storyButtons_dark
        }
    val stringResId: Int = if (isRead) R.string.story_mark_unread_state else R.string.story_mark_read_state
    this.text = context.getString(stringResId)
    this.setTextAppearance(styleResId)
}
