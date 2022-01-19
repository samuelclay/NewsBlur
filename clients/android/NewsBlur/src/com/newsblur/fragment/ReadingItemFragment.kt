package com.newsblur.fragment

import android.content.*
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.text.TextUtils
import android.util.Log
import android.view.*
import android.view.ContextMenu.ContextMenuInfo
import android.webkit.WebView.HitTestResult
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.widget.PopupMenu
import androidx.core.content.ContextCompat
import androidx.fragment.app.DialogFragment
import androidx.lifecycle.lifecycleScope
import com.google.android.material.chip.Chip
import com.newsblur.R
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.Reading
import com.newsblur.databinding.FragmentReadingitemBinding
import com.newsblur.databinding.IncludeReadingItemCommentBinding
import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import com.newsblur.domain.UserDetails
import com.newsblur.network.APIManager
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_INTEL
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_SOCIAL
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_STORY
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_TEXT
import com.newsblur.service.OriginalTextService
import com.newsblur.util.*
import com.newsblur.util.PrefConstants.ThemeValue
import java.util.*
import java.util.regex.Pattern
import kotlin.math.roundToInt

class ReadingItemFragment : NbFragment(), PopupMenu.OnMenuItemClickListener {

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
    private var textSizeReceiver: BroadcastReceiver? = null
    private var readingFontReceiver: BroadcastReceiver? = null
    private var displayFeedDetails = false
    private var user: UserDetails? = null

    var selectedViewMode: DefaultFeedView? = null
        private set

    private var textViewUnavailable = false
    private var storyChangesState: StoryChangesState? = StoryChangesState.SHOW_CHANGES

    /** The story HTML, as provided by the 'content' element of the stories API.  */
    private var storyContent: String? = null

    /** The text-mode story HTML, as retrieved via the secondary original text API.  */
    private var originalText: String? = null
    private var imageAltTexts: HashMap<String, String>? = null
    private var imageUrlRemaps: HashMap<String, String>? = null
    private var sourceUserId: String? = null
    private var contentHash = 0

    // these three flags are progressively set by async callbacks and unioned
    // to set isLoadFinished, when we trigger any final UI tricks.
    private var isContentLoadFinished = false
    private var isWebLoadFinished = false
    private var isSocialLoadFinished = false
    private var isLoadFinished = false
    private var savedScrollPosRel = 0f
    private val webViewContentMutex = Any()

    private lateinit var binding: FragmentReadingitemBinding
    private lateinit var itemCommentBinding: IncludeReadingItemCommentBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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

        user = PrefsUtils.getUserDetails(requireActivity())
        textSizeReceiver = TextSizeReceiver()

        requireActivity().registerReceiver(textSizeReceiver, IntentFilter(TEXT_SIZE_CHANGED))
        readingFontReceiver = ReadingFontReceiver()
        requireActivity().registerReceiver(readingFontReceiver, IntentFilter(READING_FONT_CHANGED))

        if (savedInstanceState != null) {
            savedScrollPosRel = savedInstanceState.getFloat(BUNDLE_SCROLL_POS_REL)
            // we can't actually use the saved scroll position until the webview finishes loading
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        val heightm = binding.readingScrollview.getChildAt(0).measuredHeight
        val pos = binding.readingScrollview.scrollY
        outState.putFloat(BUNDLE_SCROLL_POS_REL, pos.toFloat() / heightm)
    }

    override fun onDestroy() {
        requireActivity().unregisterReceiver(textSizeReceiver)
        requireActivity().unregisterReceiver(readingFontReceiver)
        binding.readingWebview.setOnTouchListener(null)
        binding.root.setOnTouchListener(null)
        requireActivity().window.decorView.setOnSystemUiVisibilityChangeListener(null)
        super.onDestroy()
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

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        val view = inflater.inflate(R.layout.fragment_readingitem, container, false)
        binding = FragmentReadingitemBinding.bind(view)
        itemCommentBinding = IncludeReadingItemCommentBinding.bind(binding.root)

        val readingActivity = requireActivity() as Reading
        fs = readingActivity.fs

        selectedViewMode = PrefsUtils.getDefaultViewModeForFeed(readingActivity, story!!.feedId)

        registerForContextMenu(binding.readingWebview)
        binding.readingWebview.setCustomViewLayout(binding.customViewContainer)
        binding.readingWebview.setWebviewWrapperLayout(binding.readingContainer)
        binding.readingWebview.setBackgroundColor(Color.TRANSPARENT)
        binding.readingWebview.fragment = this
        binding.readingWebview.activity = readingActivity

        setupItemMetadata()
        updateTrainButton()
        updateShareButton()
        updateSaveButton()
        setupItemCommentsAndShares()

        binding.readingScrollview.registerScrollChangeListener(readingActivity)

        return view
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.storyContextMenuButton.setOnClickListener { onClickMenuButton() }
        itemCommentBinding.trainStoryButton.setOnClickListener { clickTrain() }
        itemCommentBinding.saveStoryButton.setOnClickListener { clickSave() }
        itemCommentBinding.shareStoryButton.setOnClickListener { clickShare() }
    }

    override fun onCreateContextMenu(menu: ContextMenu, v: View, menuInfo: ContextMenuInfo?) {
        val result = binding.readingWebview.hitTestResult
        if (result.type == HitTestResult.IMAGE_TYPE ||
                result.type == HitTestResult.SRC_IMAGE_ANCHOR_TYPE) {
            // if the long-pressed item was an image, see if we can pop up a little dialogue
            // that presents the alt text.  Note that images wrapped in links tend to get detected
            // as anchors, not images, and may not point to the corresponding image URL.
            var imageURL = result.extra
            imageURL = imageURL!!.replace("file://", "")
            val mappedURL = imageUrlRemaps!![imageURL]
            val finalURL: String = mappedURL ?: imageURL
            val altText = imageAltTexts!![finalURL]
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
            builder.setPositiveButton(actionRID, object : DialogInterface.OnClickListener {
                override fun onClick(dialog: DialogInterface, id: Int) {
                    val i = Intent(Intent.ACTION_VIEW)
                    i.data = Uri.parse(finalURL)
                    try {
                        startActivity(i)
                    } catch (e: Exception) {
                        Log.wtf(this.javaClass.name, "device cannot open URLs")
                    }
                }
            })
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

    private fun onClickMenuButton() {
        val pm = PopupMenu(requireActivity(), binding.storyContextMenuButton)
        val menu = pm.menu
        pm.menuInflater.inflate(R.menu.story_context, menu)

        menu.findItem(R.id.menu_reading_save).setTitle(if (story!!.starred) R.string.menu_unsave_story else R.string.menu_save_story)
        if (fs!!.isFilterSaved || fs!!.isAllSaved || fs!!.singleSavedTag != null) menu.findItem(R.id.menu_reading_markunread).isVisible = false

        when (PrefsUtils.getSelectedTheme(requireContext())) {
            ThemeValue.LIGHT -> menu.findItem(R.id.menu_theme_light).isChecked = true
            ThemeValue.DARK -> menu.findItem(R.id.menu_theme_dark).isChecked = true
            ThemeValue.BLACK -> menu.findItem(R.id.menu_theme_black).isChecked = true
            ThemeValue.AUTO -> menu.findItem(R.id.menu_theme_auto).isChecked = true
            else -> {
            }
        }

        pm.setOnMenuItemClickListener(this)
        pm.show()
    }

    override fun onMenuItemClick(item: MenuItem): Boolean = when (item.itemId) {
        R.id.menu_reading_original -> {
            val i = Intent(Intent.ACTION_VIEW)
            i.data = Uri.parse(story!!.permalink)
            try {
                startActivity(i)
            } catch (e: Exception) {
                com.newsblur.util.Log.e(this, "device cannot open URLs")
            }
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
            FeedUtils.sendStoryUrl(story, requireContext())
            true
        }
        R.id.menu_send_story_full -> {
            FeedUtils.sendStoryFull(story, requireContext())
            true
        }
        R.id.menu_textsize -> {
            val textSize = TextSizeDialogFragment.newInstance(PrefsUtils.getTextSize(requireContext()), TextSizeDialogFragment.TextSizeType.ReadingText)
            textSize.show(requireActivity().supportFragmentManager, TextSizeDialogFragment::class.java.name)
            true
        }
        R.id.menu_font -> {
            val storyFont = ReadingFontDialogFragment.newInstance(PrefsUtils.getFontString(requireContext()))
            storyFont.show(requireActivity().supportFragmentManager, ReadingFontDialogFragment::class.java.name)
            true
        }
        R.id.menu_reading_save -> {
            if (story!!.starred) {
                FeedUtils.setStorySaved(story!!, false, requireContext(), null)
            } else {
                FeedUtils.setStorySaved(story!!.storyHash, true, requireContext())
            }
            true
        }
        R.id.menu_reading_markunread -> {
            FeedUtils.markStoryUnread(story!!, requireContext())
            true
        }
        R.id.menu_theme_auto -> {
            PrefsUtils.setSelectedTheme(requireContext(), ThemeValue.AUTO)
            UIUtils.restartActivity(requireActivity())
            true
        }
        R.id.menu_theme_light -> {
            PrefsUtils.setSelectedTheme(requireContext(), ThemeValue.LIGHT)
            UIUtils.restartActivity(requireActivity())
            true
        }
        R.id.menu_theme_dark -> {
            PrefsUtils.setSelectedTheme(requireContext(), ThemeValue.DARK)
            UIUtils.restartActivity(requireActivity())
            true
        }
        R.id.menu_theme_black -> {
            PrefsUtils.setSelectedTheme(requireContext(), ThemeValue.BLACK)
            UIUtils.restartActivity(requireActivity())
            true
        }
        R.id.menu_intel -> {
            // check against training on feedless stories
            if (story!!.feedId != "0") {
                clickTrain()
            }
            true
        }
        R.id.menu_go_to_feed -> {
            FeedItemsList.startActivity(context, fs, FeedUtils.getFeed(story!!.feedId), null)
            true
        }
        else -> {
            super.onOptionsItemSelected(item)
        }
    }

    private fun clickTrain() {
        val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
        intelFrag.show(requireActivity().supportFragmentManager, StoryIntelTrainerFragment::class.java.name)
    }

    private fun updateTrainButton() {
        itemCommentBinding.trainStoryButton.visibility = if (story!!.feedId == "0") View.GONE else View.VISIBLE
    }

    private fun clickSave() {
        if (story!!.starred) {
            FeedUtils.setStorySaved(story!!.storyHash, false, requireContext())
        } else {
            FeedUtils.setStorySaved(story!!.storyHash, true, requireContext())
        }
    }

    private fun updateSaveButton() {
        itemCommentBinding.saveStoryButton.setText(if (story!!.starred) R.string.unsave_this else R.string.save_this)
    }

    private fun clickShare() {
        val newFragment: DialogFragment = ShareDialogFragment.newInstance(story, sourceUserId)
        newFragment.show(parentFragmentManager, "dialog")
    }

    private fun updateShareButton() {
        for (userId in story!!.sharedUserIds) {
            if (TextUtils.equals(userId, user!!.id)) {
                itemCommentBinding.shareStoryButton.setText(R.string.already_shared)
                return
            }
        }
        itemCommentBinding.shareStoryButton.setText(R.string.share_this)
    }

    private fun setupItemCommentsAndShares() {
        SetupCommentSectionTask(this, binding.root, layoutInflater, story).execute()
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
        binding.itemFeedBorder.setBackgroundColor(Color.parseColor("#$feedBorder"))

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
            FeedUtils.iconLoader!!.displayImage(feedIconUrl, binding.readingFeedIcon)
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
            val savedTimestampText = String.format(resources.getString(R.string.story_saved_timestamp),
                    StoryUtils.formatLongDate(activity, story!!.starredTimestamp))
            binding.readingItemSavedTimestamp.visibility = View.VISIBLE
            binding.readingItemSavedTimestamp.text = savedTimestampText
        }

        binding.readingItemAuthors.setOnClickListener(View.OnClickListener {
            if (story!!.feedId == "0") return@OnClickListener  // cannot train on feedless stories
            val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
            intelFrag.show(parentFragmentManager, StoryIntelTrainerFragment::class.java.name)
        })
        binding.readingFeedTitle.setOnClickListener(View.OnClickListener {
            if (story!!.feedId == "0") return@OnClickListener  // cannot train on feedless stories
            val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
            intelFrag.show(parentFragmentManager, StoryIntelTrainerFragment::class.java.name)
        })
        binding.readingItemTitle.setOnClickListener(object : View.OnClickListener {
            override fun onClick(v: View) {
                try {
                    UIUtils.handleUri(requireContext(), Uri.parse(story!!.permalink))
                } catch (t: Throwable) {
                    // we don't actually know if the user will successfully be able to open whatever string
                    // was in the permalink or if the Intent could throw errors
                    Log.e(this.javaClass.name, "Error opening story by permalink URL.", t)
                }
            }
        })

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
                        chip.chipIcon = ContextCompat.getDrawable(requireContext(), R.drawable.ic_thumb_up)
                    }
                    Classifier.DISLIKE -> {
                        chip.setChipBackgroundColorResource(R.color.tag_red)
                        chip.setTextColor(ContextCompat.getColor(requireContext(), R.color.tag_red_text))
                        chip.chipIcon = ContextCompat.getDrawable(requireContext(), R.drawable.ic_thumb_down)
                    }
                }
            }

            // tapping tags in saved stories doesn't bring up training
            if (!(fs!!.isAllSaved || fs!!.singleSavedTag != null)) {
                v.setOnClickListener {
                    if (story!!.feedId == "0") return@setOnClickListener   // cannot train on feedless stories
                    val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
                    intelFrag.show(parentFragmentManager, StoryIntelTrainerFragment::class.java.name)
                }
            }

            binding.readingItemTags.addView(v)
        }

        binding.readingItemUserTags.removeAllViews()
        if (story!!.userTags.isNotEmpty()) {
            for (i in 0..story!!.userTags.size) {
                val v = layoutInflater.inflate(R.layout.chip_view, null)
                val chip: Chip = v.findViewById(R.id.chip)
                if (i < story!!.userTags.size) {
                    chip.text = story!!.userTags[i]
                    chip.chipIcon = ContextCompat.getDrawable(requireContext(), R.drawable.tag)
                } else {
                    chip.text = getString(R.string.add_tag)
                    chip.chipIcon = ContextCompat.getDrawable(requireContext(), R.drawable.ic_add_gray75)
                }
                v.setOnClickListener {
                    val userTagsFragment = StoryUserTagsFragment.newInstance(story!!, fs!!)
                    userTagsFragment.show(childFragmentManager, StoryUserTagsFragment::class.java.name)
                }
                binding.readingItemUserTags.addView(v)
            }
            binding.readingItemUserTags.visibility = View.VISIBLE
        }

        if (!TextUtils.isEmpty(story!!.authors)) {
            binding.readingItemAuthors.text = "•   " + story!!.authors
            if (classifier != null && classifier!!.authors.containsKey(story!!.authors)) {
                when (classifier!!.authors[story!!.authors]) {
                    Classifier.LIKE -> binding.readingItemAuthors.setTextColor(ContextCompat.getColor(requireContext(), R.color.positive))
                    Classifier.DISLIKE -> binding.readingItemAuthors.setTextColor(ContextCompat.getColor(requireContext(), R.color.negative))
                    else -> binding.readingItemAuthors.setTextColor(UIUtils.getThemedColor(requireContext(), R.attr.readingItemMetadata, android.R.attr.textColor))
                }
            }
        }

        var title = story!!.title
        title = UIUtils.colourTitleFromClassifier(title, classifier)
        binding.readingItemTitle.text = UIUtils.fromHtml(title)
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
        PrefsUtils.setDefaultViewModeForFeed(requireContext(), story!!.feedId, newMode)
    }

    fun viewModeChanged() {
        synchronized(selectedViewMode!!) {
            selectedViewMode = PrefsUtils.getDefaultViewModeForFeed(requireContext(), story!!.feedId)
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
                    loadOriginalText()
                    // still show the story mode version, as the text mode one may take some time
                    needStoryContent = true
                }
                else -> {
                    setupWebview(originalText!!)
                    onContentLoadFinished()
                }
            }
        }

        if (needStoryContent) {
            if (storyContent == null) {
                loadStoryContent()
            } else {
                setupWebview(storyContent!!)
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
            com.newsblur.util.Log.d(this, "prevented story list index offset shift")
            return
        }
        this.story = story
        //if (AppConstants.VERBOSE_LOG) com.newsblur.util.Log.d(this, "got fresh story");
    }

    fun handleUpdate(updateType: Int) {
        if (updateType and UPDATE_STORY != 0) {
            updateSaveButton()
            updateShareButton()
            setupItemCommentsAndShares()
        }
        if (updateType and UPDATE_TEXT != 0) {
            reloadStoryContent()
        }
        if (updateType and UPDATE_SOCIAL != 0) {
            updateShareButton()
            setupItemCommentsAndShares()
        }
        if (updateType and UPDATE_INTEL != 0) {
            classifier = FeedUtils.dbHelper!!.getClassifierForFeed(story!!.feedId)
            setupTagsAndIntel()
        }
    }

    private fun loadOriginalText() {
        story?.let { story ->
            lifecycleScope.executeAsyncTask(
                    doInBackground = {
                        FeedUtils.getStoryText(story.storyHash)
                    },
                    onPostExecute = { result ->
                        if (result != null) {
                            if (OriginalTextService.NULL_STORY_TEXT == result) {
                                // the server reported that text mode is not available.  kick back to story mode
                                com.newsblur.util.Log.d(this, "orig text not avail for story: " + story.storyHash)
                                textViewUnavailable = true
                            } else {
                                originalText = result
                            }
                            reloadStoryContent()
                        } else {
                            com.newsblur.util.Log.d(this, "orig text not yet cached for story: " + story.storyHash)
                            OriginalTextService.addPriorityHash(story.storyHash)
                            triggerSync()
                        }
                    }
            )
        }
    }

    private fun loadStoryContent() {
        story?.let { story ->
            lifecycleScope.executeAsyncTask(
                    doInBackground = {
                        FeedUtils.getStoryContent(story.storyHash)
                    },
                    onPostExecute = { result ->
                        if (result != null) {
                            storyContent = result
                            reloadStoryContent()
                        } else {
                            com.newsblur.util.Log.w(this, "couldn't find story content for existing story.")
                            activity?.finish()
                        }
                    }
            )
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
                        val apiManager = APIManager(requireContext())
                        apiManager.getStoryChanges(story.storyHash, showChanges)
                    },
                    onPostExecute = { response ->
                        if (!response.isError && response.story != null) {
                            storyContent = response.story.content
                            reloadStoryContent()
                            binding.readingStoryChanges.setText(if (showChanges) R.string.story_hide_changes else R.string.story_show_changes)
                            storyChangesState = if (showChanges) StoryChangesState.HIDE_CHANGES else StoryChangesState.SHOW_CHANGES
                        } else {
                            binding.readingStoryChanges.setText(if (showChanges) R.string.story_show_changes else R.string.story_hide_changes)
                        }
                    }
            )
        }
    }

    private fun setupWebview(storyText: String) {
        // sometimes we get called before the activity is ready. abort, since we will get a refresh when
        // the cursor loads
        activity?.let {
            it.runOnUiThread { _setupWebview(storyText) }
        }
    }

    private fun _setupWebview(storyTextString: String) {
        var storyText = storyTextString
        if (activity == null) {
            // this method gets called by async UI bits that might hold stale fragment references with no assigned
            // activity.  If this happens, just abort the call.
            return
        }
        synchronized(webViewContentMutex) {
            // this method might get called repeatedly despite no content change, which is expensive
            val contentHash = storyText.hashCode()
            if (this.contentHash == contentHash) return
            this.contentHash = contentHash

            sniffAltTexts(storyText)

            storyText = swapInOfflineImages(storyText)
            val currentSize = PrefsUtils.getTextSize(requireContext())
            val font = PrefsUtils.getFont(requireContext())
            val themeValue = PrefsUtils.getSelectedTheme(requireContext())

            val builder = StringBuilder()
            builder.append("<html><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1, minimum-scale=1, user-scalable=0\" />")
            builder.append(font.forWebView(currentSize))
            builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"reading.css\" />")
            when (themeValue) {
                ThemeValue.LIGHT -> {
                    //                builder.append("<meta name=\"color-scheme\" content=\"light\"/>");
                    //                builder.append("<meta name=\"supported-color-schemes\" content=\"light\"/>");
                    builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"light_reading.css\" />")
                }
                ThemeValue.DARK -> {
                    builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"dark_reading.css\" />")
                }
                ThemeValue.BLACK -> {
                    builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"black_reading.css\" />")
                }
                ThemeValue.AUTO -> {
                    when (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) {
                        Configuration.UI_MODE_NIGHT_YES -> {
                            builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"dark_reading.css\" />")
                        }
                        Configuration.UI_MODE_NIGHT_NO -> {
                            builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"light_reading.css\" />")
                        }
                        Configuration.UI_MODE_NIGHT_UNDEFINED -> {
                            builder.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"light_reading.css\" />")
                        }
                    }
                }
                else -> {
                }
            }

            builder.append("</head><body><div class=\"NB-story\">")
            builder.append(storyText)
            builder.append("<script type=\"text/javascript\" src=\"storyDetailView.js\"></script>")
            builder.append("</div></body></html>")
            binding.readingWebview.loadDataWithBaseURL("file:///android_asset/", builder.toString(), "text/html", "UTF-8", null)
        }
    }

    private fun sniffAltTexts(html: String) {
        // Find images with alt tags and cache the text for use on long-press
        //   NOTE: if doing this via regex has a smell, you have a good nose!  This method is far from perfect
        //   and may miss valid cases or trucate tags, but it works for popular feeds (read: XKCD) and doesn't
        //   require us to import a proper parser lib of hundreds of kilobytes just for this one feature.
        imageAltTexts = HashMap()
        // sniff for alts first
        var imgTagMatcher = altSniff1.matcher(html)
        while (imgTagMatcher.find()) {
            imageAltTexts!![imgTagMatcher.group(2)] = imgTagMatcher.group(4)
        }
        imgTagMatcher = altSniff2.matcher(html)
        while (imgTagMatcher.find()) {
            imageAltTexts!![imgTagMatcher.group(4)] = imgTagMatcher.group(2)
        }
        // then sniff for 'title' tags, so they will overwrite alts and take precedence
        imgTagMatcher = altSniff3.matcher(html)
        while (imgTagMatcher.find()) {
            imageAltTexts!![imgTagMatcher.group(2)] = imgTagMatcher.group(4)
        }
        imgTagMatcher = altSniff4.matcher(html)
        while (imgTagMatcher.find()) {
            imageAltTexts!![imgTagMatcher.group(4)] = imgTagMatcher.group(2)
        }

        // while were are at it, create a place where we can later cache offline image remaps so that when
        // we do an alt-text lookup, we can search for the right URL key.
        imageUrlRemaps = HashMap()
    }

    private fun swapInOfflineImages(htmlString: String): String {
        var html = htmlString
        val imageTagMatcher = imgSniff.matcher(html)
        while (imageTagMatcher.find()) {
            val url = imageTagMatcher.group(2)
            val localPath = FeedUtils.storyImageCache!!.getCachedLocation(url) ?: continue
            html = html.replace(imageTagMatcher.group(1) + "\"" + url + "\"", "src=\"$localPath\"")
            imageUrlRemaps!![localPath] = url
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
        if (!isWebLoadFinished) {
            binding.readingWebview.evaluateJavascript("loadImages();", null)
        }
        isWebLoadFinished = true
        checkLoadStatus()
    }

    /** The social UI has finished loading from the DB.  */
    fun onSocialLoadFinished() {
        isSocialLoadFinished = true
        checkLoadStatus()
    }

    private fun checkLoadStatus() {
        synchronized(isLoadFinished) {
            if (isContentLoadFinished && isWebLoadFinished && isSocialLoadFinished) {
                // iff this is the first time all content has finished loading, trigger any UI
                // behaviour that is position-dependent
                if (!isLoadFinished) {
                    onLoadFinished()
                }
                isLoadFinished = true
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

    fun flagWebviewError() {
        // TODO: enable a selective reload mechanism on load failures?
    }

    private inner class TextSizeReceiver : BroadcastReceiver() {

        override fun onReceive(context: Context, intent: Intent) {
            binding.readingWebview.setTextSize(intent.getFloatExtra(TEXT_SIZE_VALUE, 1.0f))
        }
    }

    private inner class ReadingFontReceiver : BroadcastReceiver() {

        override fun onReceive(context: Context, intent: Intent) {
            contentHash = 0 // Force reload since content hasn't changed
            reloadStoryContent()
        }
    }

    companion object {
        private const val BUNDLE_SCROLL_POS_REL = "scrollStateRel"
        const val TEXT_SIZE_CHANGED = "textSizeChanged"
        const val TEXT_SIZE_VALUE = "textSizeChangeValue"
        const val READING_FONT_CHANGED = "readingFontChanged"

        @JvmStatic
        fun newInstance(story: Story?, feedTitle: String?, feedFaviconColor: String?, feedFaviconFade: String?, feedFaviconBorder: String?, faviconText: String?, faviconUrl: String?, classifier: Classifier?, displayFeedDetails: Boolean, sourceUserId: String?): ReadingItemFragment {
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

        private val altSniff1 = Pattern.compile("<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*alt=(['\"])((?:(?!\\3).)*)\\3[^>]*>", Pattern.CASE_INSENSITIVE)
        private val altSniff2 = Pattern.compile("<img[^>]*alt=(['\"])((?:(?!\\1).)*)\\1[^>]*src=(['\"])((?:(?!\\3).)*)\\3[^>]*>", Pattern.CASE_INSENSITIVE)
        private val altSniff3 = Pattern.compile("<img[^>]*src=(['\"])((?:(?!\\1).)*)\\1[^>]*title=(['\"])((?:(?!\\3).)*)\\3[^>]*>", Pattern.CASE_INSENSITIVE)
        private val altSniff4 = Pattern.compile("<img[^>]*title=(['\"])((?:(?!\\1).)*)\\1[^>]*src=(['\"])((?:(?!\\3).)*)\\3[^>]*>", Pattern.CASE_INSENSITIVE)
        private val imgSniff = Pattern.compile("<img[^>]*(src\\s*=\\s*)\"([^\"]*)\"[^>]*>", Pattern.CASE_INSENSITIVE)
    }
}