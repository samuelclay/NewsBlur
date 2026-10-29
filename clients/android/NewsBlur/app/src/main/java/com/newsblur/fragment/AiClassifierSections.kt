package com.newsblur.fragment

import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.Editable
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.TextWatcher
import android.text.method.LinkMovementMethod
import android.text.style.ClickableSpan
import android.text.style.StyleSpan
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.activity.UsageBillingActivity
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.IncludeAiClassifierSectionBinding
import com.newsblur.databinding.IncludeAiPromptRowBinding
import com.newsblur.design.AiClassifierPalette
import com.newsblur.domain.Classifier
import com.newsblur.domain.ClassifierScope
import com.newsblur.domain.Folder
import com.newsblur.domain.Story
import com.newsblur.network.ClassifierApi
import com.newsblur.network.PromptTestRequest
import com.newsblur.network.domain.AiCostEstimate
import com.newsblur.network.domain.PromptTestResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.AppConstants
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UsageBillingAction
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/**
 * The trainer's Natural Language Text Classifier and Natural Language Image Classifier sections,
 * ported from media/js/newsblur/reader/reader_classifier.js make_content_filter_section and
 * make_image_filter_section. Saved prompts toggle between focus and hidden or get removed, a new
 * prompt can be typed (with a live preview) and tested on the current story, and the section
 * shows the monthly cost estimate and the billing or limit banners.
 *
 * Prompt edits go straight into [classifier]. Call [commit] right before the trainer saves.
 */
class AiClassifierSections(
    private val fragment: Fragment,
    private val container: ViewGroup,
    private val classifier: Classifier,
    // Null in FeedIntelTrainerFragment.java, which has no story to test or images to show.
    private val story: Story?,
    private val feedId: String,
    theme: ThemeValue,
    private val prefsRepo: PrefsRepo,
    private val dbHelper: BlurDatabaseHelper,
    private val classifierApi: ClassifierApi,
    private val thumbnailLoader: ImageLoader,
) {
    private val context: Context = fragment.requireContext()
    private val inflater = LayoutInflater.from(context)
    private val colors = AiClassifierPalette.colors(theme)
    private val original = classifier.copyPrompts()
    private var billing = prefsRepo.getUsageBillingState()
    private var costEstimate: AiCostEstimate? = null
    private var limitReached = false
    private val feedStories = dbHelper.getFeed(feedId)?.storiesLastMonth ?: 0
    private val storiesByFeed: Map<String, Int> by lazy { dbHelper.getStoriesLastMonthByFeed() }
    private val folders by lazy { dbHelper.getFolders() }
    private val sections = listOf(Section(imagePrompt = false), Section(imagePrompt = true))

    fun bind() {
        sections.forEach { it.bind() }
        fetchUsage()
    }

    /**
     * Keeps a typed but unadded prompt, since the web saves its live preview pill too, and records
     * the folder and global prompt changes that need their own save requests.
     */
    fun commit() {
        sections.forEach { it.commitTypedPrompt() }
        classifier.recordScopedPromptChanges(original)
    }

    private fun fetchUsage() {
        fragment.lifecycleScope.launch {
            val usage = withContext(Dispatchers.IO) { classifierApi.getAiClassifierUsage(feedId) }
            if (!fragment.isAdded || usage.code != 0) return@launch
            // AiClassifierSections.kt trusts the server over a stale /reader/feeds sync, such as
            // right after billing was set up on the web.
            if (usage.canUseAi != billing.canUseAiClassifiers) {
                billing = billing.copy(canUseAiClassifiers = usage.canUseAi)
                prefsRepo.setUsageBillingState(billing)
            }
            if (usage.canUseAi) {
                costEstimate = usage.costEstimate
                limitReached = usage.isLimitReached
            }
            sections.forEach { it.refresh() }
        }
    }

    private fun openBilling() {
        context.startActivity(Intent(context, UsageBillingActivity::class.java))
    }

    private fun canUseWiderScopes(): Boolean = prefsRepo.getIsArchive() || prefsRepo.getIsPro()

    private val feedFolderPath: String? by lazy { folderPathOfFeed(folders, feedId) }

    private fun storiesForScope(scope: ClassifierScope): Int =
        when {
            scope.scope == ClassifierScope.GLOBAL -> storiesByFeed.values.sum()
            scope.scope == ClassifierScope.FOLDER -> {
                val folder = folders.firstOrNull { folderPath(it) == scope.folderName }
                folder?.feedIds?.sumOf { storiesByFeed[it] ?: 0 } ?: 0
            }
            else -> feedStories
        }

    private fun dp(value: Int): Int = (value * context.resources.displayMetrics.density).roundToInt()

    private fun rounded(
        fill: Int,
        stroke: Int? = null,
        radiusDp: Int = 6,
    ) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = dp(radiusDp).toFloat()
        setColor(fill)
        if (stroke != null) setStroke(dp(1), stroke)
    }

    private fun isActive(score: Int?): Boolean = score == Classifier.LIKE || score == Classifier.DISLIKE

    private inner class Section(
        val imagePrompt: Boolean,
    ) {
        val binding = IncludeAiClassifierSectionBinding.inflate(inflater, container, false)
        val scores: LinkedHashMap<String, Int>
            get() = if (imagePrompt) classifier.imagePrompts else classifier.prompts
        var previewScore = Classifier.LIKE
        var previewScope = ClassifierScope.FEED_SCOPE
        val imageUrls: List<String> = if (imagePrompt && story != null) dbHelper.getStoryImageUrls(story.storyHash) else emptyList()
        val thumbs = mutableListOf<Pair<FrameLayout, TextView>>()
        val tester = AiPromptTester(fragment.lifecycleScope, classifierApi)

        val typedPrompt: String
            get() = binding.aiPromptInput.text.toString().trim()

        val draft: AiPromptDraft
            get() = AiPromptDraft(typedPrompt, hidden = previewScore == Classifier.DISLIKE)

        fun bind() {
            container.addView(binding.root)
            binding.root.background = rounded(colors.cardBackground, colors.cardBorder, radiusDp = 8)
            binding.aiSectionIcon.setImageResource(if (imagePrompt) R.drawable.ic_ai_image_filter else R.drawable.ic_ai_text_filter)
            binding.aiSectionIcon.imageTintList = ColorStateList.valueOf(colors.textSecondary)
            binding.aiSectionTitle.setText(if (imagePrompt) R.string.ai_image_classifier_header else R.string.ai_text_classifier_header)
            binding.aiSectionTitle.setTextColor(colors.textPrimary)
            binding.aiSectionExplainer.setText(
                if (imagePrompt) R.string.ai_image_classifier_explainer else R.string.ai_text_classifier_explainer,
            )
            binding.aiSectionExplainer.setTextColor(colors.textSecondary)
            binding.aiCostBox.background = rounded(colors.costBackground, colors.costBorder)
            binding.aiCostAmounts.setTextColor(colors.textPrimary)
            binding.aiCostBreakdown.setTextColor(colors.textSecondary)
            styleButton(binding.aiCostBillingButton)
            binding.aiCostBillingButton.setOnClickListener { openBilling() }

            binding.aiPromptInput.setHint(if (imagePrompt) R.string.ai_image_prompt_hint else R.string.ai_text_prompt_hint)
            binding.aiPromptInput.background = rounded(colors.inputBackground, colors.cardBorder)
            binding.aiPromptInput.setTextColor(colors.textPrimary)
            binding.aiPromptInput.setHintTextColor(colors.textSecondary)
            binding.aiPromptInput.addTextChangedListener(
                object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit

                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit

                    override fun afterTextChanged(s: Editable?) {
                        clearTestResults()
                        refresh()
                    }
                },
            )
            // Like pressing Enter on the web, Done adds the typed prompt to the saved list.
            binding.aiPromptInput.setOnEditorActionListener { _, actionId, _ ->
                if (actionId != EditorInfo.IME_ACTION_DONE || typedPrompt.isEmpty()) return@setOnEditorActionListener false
                addTypedPrompt()
                true
            }

            val canTest = story != null && (!imagePrompt || imageUrls.isNotEmpty())
            binding.aiTestButton.isVisible = canTest
            styleButton(binding.aiTestButton)
            binding.aiTestButton.setText(testLabel())
            binding.aiTestButton.setOnClickListener { runTest() }

            bindImageGrid()
            bindPreviewRow()
            renderSavedList()
            refresh()
        }

        fun commitTypedPrompt() {
            if (typedPrompt.isNotEmpty()) addTypedPrompt()
        }

        private fun addTypedPrompt() {
            val prompt = typedPrompt
            scores[prompt] = previewScore
            classifier.setPromptScope(imagePrompt, prompt, previewScope)
            binding.aiPromptInput.setText("")
            previewScore = Classifier.LIKE
            previewScope = ClassifierScope.FEED_SCOPE
            renderSavedList()
            refresh()
        }

        fun refresh() {
            renderPreviewRow()
            binding.aiTestButton.isEnabled = typedPrompt.isNotEmpty() && !tester.isTesting
            binding.aiTestButton.alpha = if (binding.aiTestButton.isEnabled) 1f else 0.5f
            renderCost()
            renderBanner()
        }

        private fun styleButton(button: com.google.android.material.button.MaterialButton) {
            button.backgroundTintList = ColorStateList.valueOf(colors.accent)
            button.setTextColor(colors.accentText)
        }

        private fun testLabel(): Int =
            when {
                !imagePrompt -> R.string.ai_test_story
                imageUrls.size == 1 -> R.string.ai_test_image
                else -> R.string.ai_test_images
            }

        private fun bindImageGrid() {
            if (imageUrls.isEmpty()) return
            binding.aiImageGridScroll.isVisible = true
            imageUrls.forEachIndexed { index, url ->
                val frame = FrameLayout(context)
                val size = dp(76)
                frame.layoutParams =
                    LinearLayout.LayoutParams(size, size).apply { if (index > 0) marginStart = dp(6) }
                frame.background = rounded(colors.inputBackground, colors.cardBorder)
                frame.setPadding(dp(2), dp(2), dp(2), dp(2))
                val image = ImageView(context)
                image.scaleType = ImageView.ScaleType.CENTER_CROP
                image.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
                frame.addView(image, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
                val label = TextView(context)
                label.textSize = 10f
                label.gravity = Gravity.CENTER
                label.setPadding(dp(2), dp(1), dp(2), dp(1))
                label.isVisible = false
                frame.addView(
                    label,
                    FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM),
                )
                // AiClassifierSections.kt loads http images over https, since cleartext is blocked.
                thumbnailLoader.displayImage(url.replaceFirst("http://", "https://"), image)
                binding.aiImageGrid.addView(frame)
                thumbs.add(frame to label)
            }
        }

        private fun bindPreviewRow() {
            val row = binding.aiPreviewRow
            row.aiPromptClear.isVisible = false
            row.aiPromptLike.setOnClickListener { choosePreviewScore(Classifier.LIKE) }
            row.aiPromptDislike.setOnClickListener { choosePreviewScore(Classifier.DISLIKE) }
            bindScopeButtons(row) { scope ->
                previewScope = scope
                refresh()
            }
        }

        // A test result answers for one direction, so flipping it clears the result like editing does.
        private fun choosePreviewScore(score: Int) {
            if (score != previewScore) clearTestResults()
            previewScore = score
            refresh()
        }

        private fun renderPreviewRow() {
            val row = binding.aiPreviewRow
            val prompt = typedPrompt
            val score = if (prompt.isEmpty()) null else previewScore
            styleLabel(row.aiPromptLabel, prompt.ifEmpty { null }, score)
            styleThumbs(row, score)
            row.aiPromptLike.isEnabled = prompt.isNotEmpty()
            row.aiPromptDislike.isEnabled = prompt.isNotEmpty()
            styleScope(row, previewScope)
        }

        private fun renderSavedList() {
            binding.aiSavedList.removeAllViews()
            for (prompt in scores.keys) {
                val row = IncludeAiPromptRowBinding.inflate(inflater, binding.aiSavedList, false)
                fun render() {
                    val score = scores[prompt]
                    styleLabel(row.aiPromptLabel, prompt, score)
                    styleThumbs(row, score)
                    styleScope(row, classifier.promptScope(imagePrompt, prompt))
                }
                row.aiPromptLike.setOnClickListener {
                    scores[prompt] = Classifier.LIKE
                    render()
                    refresh()
                }
                row.aiPromptDislike.setOnClickListener {
                    scores[prompt] = Classifier.DISLIKE
                    render()
                    refresh()
                }
                row.aiPromptClear.setOnClickListener {
                    scores[prompt] = if (scores[prompt] == Classifier.DISLIKE) Classifier.CLEAR_DISLIKE else Classifier.CLEAR_LIKE
                    render()
                    refresh()
                }
                bindScopeButtons(row) { scope ->
                    classifier.setPromptScope(imagePrompt, prompt, scope)
                    render()
                    refresh()
                }
                render()
                binding.aiSavedList.addView(row.root)
            }
        }

        /** Mirrors reader_classifier.js select_scope: folder and global need Premium Archive. */
        private fun bindScopeButtons(
            row: IncludeAiPromptRowBinding,
            onScope: (ClassifierScope) -> Unit,
        ) {
            row.aiPromptScopeFeed.setOnClickListener { onScope(ClassifierScope.FEED_SCOPE) }
            row.aiPromptScopeFolder.setOnClickListener {
                if (!canUseWiderScopes()) return@setOnClickListener scopeDenied()
                feedFolderPath?.let { onScope(ClassifierScope.folder(it)) }
            }
            row.aiPromptScopeGlobal.setOnClickListener {
                if (!canUseWiderScopes()) return@setOnClickListener scopeDenied()
                onScope(ClassifierScope.GLOBAL_SCOPE)
            }
            // A top-level feed has no folder, and a folder scope without one would save as global.
            row.aiPromptScopeFolder.isEnabled = feedFolderPath != null
        }

        private fun scopeDenied() {
            Toast.makeText(context, R.string.ai_scope_requires_archive, Toast.LENGTH_SHORT).show()
        }

        private fun styleScope(
            row: IncludeAiPromptRowBinding,
            scope: ClassifierScope,
        ) {
            val buttons =
                listOf(
                    ClassifierScope.FEED to row.aiPromptScopeFeed,
                    ClassifierScope.FOLDER to row.aiPromptScopeFolder,
                    ClassifierScope.GLOBAL to row.aiPromptScopeGlobal,
                )
            val kind = if (scope.isFeed) ClassifierScope.FEED else scope.scope
            for ((buttonScope, button) in buttons) {
                button.imageTintList = ColorStateList.valueOf(if (buttonScope == kind) colors.scopeActive else colors.scopeInactive)
                button.alpha = if (button.isEnabled) 1f else 0.4f
            }
            row.aiPromptScopeLabel.setTextColor(colors.textSecondary)
            row.aiPromptScopeLabel.text =
                when (kind) {
                    ClassifierScope.GLOBAL -> context.getString(R.string.ai_scope_global)
                    ClassifierScope.FOLDER ->
                        if (scope.folderName.isEmpty()) {
                            context.getString(R.string.ai_scope_folder)
                        } else {
                            context.getString(R.string.ai_scope_folder_named, scope.folderName)
                        }
                    else -> context.getString(R.string.ai_scope_feed)
                }
        }

        /** "Content  <prompt>" as a pill colored by focus, hidden, or neither, like the web's classifier pills. */
        private fun styleLabel(
            label: TextView,
            prompt: String?,
            score: Int?,
        ) {
            val (fill, text) =
                when (score) {
                    Classifier.LIKE -> colors.focusBackground to colors.focusText
                    Classifier.DISLIKE -> colors.hiddenBackground to colors.hiddenText
                    else -> colors.neutralBackground to colors.neutralText
                }
            label.background = rounded(fill)
            label.setTextColor(text)
            val type = context.getString(if (imagePrompt) R.string.ai_prompt_type_image else R.string.ai_prompt_type_content)
            val builder = SpannableStringBuilder(type)
            builder.setSpan(StyleSpan(Typeface.BOLD), 0, type.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            builder.append("  ")
            if (prompt == null) {
                val start = builder.length
                builder.append(context.getString(R.string.ai_prompt_placeholder))
                builder.setSpan(StyleSpan(Typeface.ITALIC), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            } else {
                builder.append(prompt)
            }
            label.text = builder
            // A removed prompt stays listed, struck through, until the trainer saves.
            val removed = score == Classifier.CLEAR_LIKE || score == Classifier.CLEAR_DISLIKE
            label.paintFlags =
                if (removed) label.paintFlags or Paint.STRIKE_THRU_TEXT_FLAG else label.paintFlags and Paint.STRIKE_THRU_TEXT_FLAG.inv()
        }

        private fun styleThumbs(
            row: IncludeAiPromptRowBinding,
            score: Int?,
        ) {
            row.aiPromptLike.setBackgroundResource(
                if (score == Classifier.LIKE) R.drawable.ic_thumb_up_green else R.drawable.ic_thumb_up_yellow,
            )
            row.aiPromptDislike.setBackgroundResource(
                if (score == Classifier.DISLIKE) R.drawable.ic_thumb_down_red else R.drawable.ic_thumb_down_yellow,
            )
        }

        private fun activeScopes(): List<ClassifierScope> {
            val saved = scores.filterValues(::isActive).keys.map { classifier.promptScope(imagePrompt, it) }
            return if (typedPrompt.isNotEmpty()) saved + previewScope else saved
        }

        private fun renderCost() {
            val estimate = costEstimate
            val summary =
                estimate?.let {
                    AiClassifierCost.estimate(
                        costPerStory = if (imagePrompt) it.avgCostPerImage else it.avgCostPerText,
                        feedStories = feedStories,
                        activeFilterScopes = activeScopes(),
                        storiesForScope = ::storiesForScope,
                    )
                }
            binding.aiCostBox.isVisible = summary != null
            if (summary == null) return
            binding.aiCostAmounts.text = AiClassifierCost.amounts(context.resources, summary)
            binding.aiCostBreakdown.text = AiClassifierCost.breakdown(context.resources, summary, imagePrompt)
            when (billing.action) {
                UsageBillingAction.MANAGE -> binding.aiCostBillingButton.setText(R.string.ai_billing_manage_limits)
                UsageBillingAction.SET_UP -> binding.aiCostBillingButton.setText(R.string.ai_billing_set_up)
                UsageBillingAction.NONE -> Unit
            }
            binding.aiCostBillingButton.isVisible = billing.action != UsageBillingAction.NONE
        }

        /** reader_classifier.js show_limit_reached_banner and make_ai_billing_banner. */
        private fun renderBanner() {
            val banner = binding.aiBanner
            val hasPrompts = scores.values.any(::isActive) || typedPrompt.isNotEmpty()
            when {
                limitReached -> {
                    banner.background = rounded(colors.limitBannerBackground, colors.limitBannerBorder)
                    banner.setTextColor(colors.limitBannerText)
                    val builder = SpannableStringBuilder()
                    val title = context.getString(R.string.ai_limit_reached_title)
                    builder.append(title)
                    builder.setSpan(StyleSpan(Typeface.BOLD), 0, title.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    builder.append(" ").append(context.getString(R.string.ai_limit_reached_body)).append(" ")
                    appendLink(builder, context.getString(R.string.ai_limit_reached_link), colors.limitBannerText)
                    showBanner(builder)
                }
                hasPrompts && !billing.canUseAiClassifiers -> {
                    banner.background = rounded(colors.billingBannerBackground, colors.billingBannerBorder)
                    banner.setTextColor(colors.billingBannerText)
                    val link = context.getString(R.string.ai_billing_banner_link)
                    val message = context.getString(R.string.ai_billing_banner, link)
                    val builder = SpannableStringBuilder(message)
                    val start = message.indexOf(link)
                    if (start >= 0) {
                        builder.setSpan(linkSpan(colors.billingBannerLink), start, start + link.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                        builder.setSpan(StyleSpan(Typeface.BOLD), start, start + link.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    }
                    showBanner(builder)
                }
                else -> banner.isVisible = false
            }
        }

        private fun showBanner(text: CharSequence) {
            binding.aiBanner.text = text
            binding.aiBanner.movementMethod = LinkMovementMethod.getInstance()
            binding.aiBanner.isVisible = true
        }

        private fun appendLink(
            builder: SpannableStringBuilder,
            text: String,
            color: Int,
        ) {
            val start = builder.length
            builder.append(text)
            builder.setSpan(linkSpan(color), start, builder.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }

        private fun linkSpan(color: Int) =
            object : ClickableSpan() {
                override fun onClick(widget: View) = openBilling()

                override fun updateDrawState(ds: TextPaint) {
                    ds.color = color
                    ds.isUnderlineText = true
                }
            }

        private fun runTest() {
            val tested = draft
            val storyHash = story?.storyHash ?: return
            if (tested.prompt.isEmpty() || tester.isTesting) return
            clearTestResults()
            binding.aiTestButton.setText(if (imagePrompt) R.string.ai_analyzing_images else R.string.ai_testing_story)
            thumbs.forEach { (frame, _) -> frame.alpha = 0.5f }
            val request = PromptTestRequest(tested.prompt, storyHash, feedId, includeImages = imagePrompt, hidden = tested.hidden)
            tester.run(request, currentDraft = { draft }) { response, isCurrent ->
                if (!fragment.isAdded) return@run
                binding.aiTestButton.setText(testLabel())
                thumbs.forEach { (frame, _) -> frame.alpha = 1f }
                response.costEstimate?.let { costEstimate = it }
                // AiClassifierSections.kt drops a result for a draft that changed mid-test, so an
                // untested prompt never looks verified.
                if (isCurrent) showTestResult(response)
                refresh()
            }
            refresh()
        }

        private fun showTestResult(response: PromptTestResponse) {
            if (!response.isSuccess) {
                val message = response.message ?: context.getString(R.string.ai_test_failed)
                showStatus(message, colors.errorBackground, colors.errorText, colors.errorBorder)
                return
            }
            if (!imagePrompt) {
                if (response.matched) {
                    showStatus(context.getString(R.string.ai_story_matches), colors.matchBackground, colors.matchText, colors.matchBorder)
                } else {
                    showStatus(
                        context.getString(R.string.ai_story_no_match),
                        colors.noMatchBackground,
                        colors.noMatchText,
                        colors.noMatchBorder,
                    )
                }
                return
            }
            thumbs.forEachIndexed { index, (frame, label) ->
                val matched = response.imageMatched(index)
                frame.background = rounded(colors.inputBackground, if (matched) colors.matchText else colors.cardBorder)
                label.setText(if (matched) R.string.ai_image_label_match else R.string.ai_image_label_no_match)
                label.setBackgroundColor(if (matched) colors.matchText else 0xB3000000.toInt())
                label.setTextColor(0xFFFFFFFF.toInt())
                label.isVisible = true
            }
            val total = imageUrls.size
            val matches = response.imageMatchCount
            when {
                matches == 0 ->
                    showStatus(
                        context.getString(if (total == 1) R.string.ai_image_no_match else R.string.ai_images_no_match),
                        colors.noMatchBackground,
                        colors.noMatchText,
                        colors.noMatchBorder,
                    )
                total == 1 ->
                    showStatus(context.getString(R.string.ai_image_matches), colors.matchBackground, colors.matchText, colors.matchBorder)
                else ->
                    showStatus(
                        context.resources.getQuantityString(R.plurals.ai_images_match, total, matches, total),
                        colors.matchBackground,
                        colors.matchText,
                        colors.matchBorder,
                    )
            }
        }

        private fun showStatus(
            text: String,
            fill: Int,
            textColor: Int,
            border: Int,
        ) {
            binding.aiTestStatus.text = text
            binding.aiTestStatus.setTextColor(textColor)
            binding.aiTestStatus.background = rounded(fill, border)
            binding.aiTestStatus.isVisible = true
        }

        private fun clearTestResults() {
            binding.aiTestStatus.isVisible = false
            thumbs.forEach { (frame, label) ->
                frame.background = rounded(colors.inputBackground, colors.cardBorder)
                label.isVisible = false
            }
        }
    }

    companion object {
        /** [folder]'s path as apps/reader/models.py flatten_folders names it, like "Blogs - Tumblrs". */
        fun folderPath(folder: Folder): String =
            (folder.parents.filter { it != AppConstants.ROOT_FOLDER } + folder.name).joinToString(" - ")

        /** The first folder holding [feedId], or null for a feed that is only at the top level. */
        fun folderPathOfFeed(
            folders: List<Folder>,
            feedId: String,
        ): String? = folders.firstOrNull { it.name != AppConstants.ROOT_FOLDER && it.feedIds.contains(feedId) }?.let(::folderPath)
    }
}
