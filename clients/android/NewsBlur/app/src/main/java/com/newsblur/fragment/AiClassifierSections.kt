package com.newsblur.fragment

import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
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
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.res.ResourcesCompat
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.activity.UsageBillingActivity
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.IncludeAiClassifierSectionBinding
import com.newsblur.design.AiClassifierPalette
import com.newsblur.design.TrainerPalette
import com.newsblur.domain.Classifier
import com.newsblur.domain.ClassifierScope
import com.newsblur.domain.Story
import com.newsblur.network.ClassifierApi
import com.newsblur.network.PromptTestRequest
import com.newsblur.network.domain.AiCostEstimate
import com.newsblur.network.domain.PromptTestResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UsageBillingAction
import com.newsblur.view.TrainerCapsuleView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/**
 * The trainer's Natural Language Text Classifier and Natural Language Image Classifier sections,
 * ported from media/js/newsblur/reader/reader_classifier.js make_content_filter_section and
 * make_image_filter_section and laid out like clients/ios/Classes/TrainerAIPromptSection.swift.
 * Saved prompts are capsules (view/TrainerCapsuleView.kt) that toggle between focus and hidden or
 * get removed, a new prompt can be typed (with a live preview capsule) and tested on the current
 * story, and the section shows the monthly cost estimate and the billing or limit banners.
 *
 * Prompt edits go straight into [classifier]. Call [commit] right before the trainer saves, then
 * Classifier.recordChanges, as IntelTrainerSections.kt does.
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
    // The classifier as the trainer opened it, from Classifier.snapshot.
    private val original: Classifier,
    private val scopePicker: TrainerScopePicker,
) {
    private val context: Context = fragment.requireContext()
    private val inflater = LayoutInflater.from(context)
    private val colors = AiClassifierPalette.colors(theme)
    private val trainerColors = TrainerPalette.colors(theme)
    private val medium: Typeface? = ResourcesCompat.getFont(context, R.font.whitney_ssm_medium_bas)
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

    /** Keeps a typed but unadded prompt, since the web saves its live preview pill too. */
    fun commit() {
        sections.forEach { it.commitTypedPrompt() }
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

    private fun storiesForScope(scope: ClassifierScope): Int =
        when {
            scope.scope == ClassifierScope.GLOBAL -> storiesByFeed.values.sum()
            scope.scope == ClassifierScope.FOLDER -> {
                val folder = folders.firstOrNull { TrainerScopePicker.folderPath(it) == scope.folderName }
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
            get() =
                binding.aiPromptInput.text
                    .toString()
                    .trim()

        val draft: AiPromptDraft
            get() = AiPromptDraft(typedPrompt, hidden = previewScore == Classifier.DISLIKE)

        fun bind() {
            container.addView(binding.root)
            // IntelTrainerSections.kt: the same header and card as the trainer's other sections.
            binding.aiSectionHeader.layoutParams = IntelTrainerSections.sectionHeaderParams(context)
            binding.aiSectionCard.layoutParams = IntelTrainerSections.sectionCardParams(context)
            IntelTrainerSections.styleCard(binding.aiSectionCard, trainerColors)
            binding.aiSectionIcon.setImageResource(if (imagePrompt) R.drawable.ic_ai_image_filter else R.drawable.ic_ai_text_filter)
            binding.aiSectionIcon.imageTintList = ColorStateList.valueOf(trainerColors.promptAccent)
            binding.aiSectionTitle.setText(if (imagePrompt) R.string.ai_image_classifier_header else R.string.ai_text_classifier_header)
            binding.aiSectionTitle.setTextColor(trainerColors.textPrimary)
            binding.aiSectionTitle.typeface = medium
            binding.aiSectionExplainer.setText(
                if (imagePrompt) R.string.ai_image_classifier_explainer else R.string.ai_text_classifier_explainer,
            )
            binding.aiSectionExplainer.setTextColor(trainerColors.textSecondary)
            binding.aiSectionExplainer.typeface = medium
            binding.aiSectionExplainer.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            binding.aiCostBox.background = rounded(trainerColors.insetBackground, radiusDp = 8)
            binding.aiCostAmounts.setTextColor(trainerColors.textPrimary)
            binding.aiCostBreakdown.setTextColor(trainerColors.textSecondary)
            styleButton(binding.aiCostBillingButton)
            binding.aiCostBillingButton.setOnClickListener { openBilling() }

            binding.aiPromptInput.setHint(if (imagePrompt) R.string.ai_image_prompt_hint else R.string.ai_text_prompt_hint)
            binding.aiPromptInput.background = rounded(trainerColors.fieldBackground, trainerColors.fieldBorder)
            binding.aiPromptInput.setTextColor(trainerColors.textPrimary)
            binding.aiPromptInput.setHintTextColor(trainerColors.textSecondary)
            binding.aiPromptInput.typeface = medium
            binding.aiPromptInput.addTextChangedListener(
                object : TextWatcher {
                    override fun beforeTextChanged(
                        s: CharSequence?,
                        start: Int,
                        count: Int,
                        after: Int,
                    ) = Unit

                    override fun onTextChanged(
                        s: CharSequence?,
                        start: Int,
                        before: Int,
                        count: Int,
                    ) = Unit

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
                frame.background = rounded(trainerColors.insetBackground, trainerColors.fieldBorder)
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

        private val preview = TrainerCapsuleView(context)

        /**
         * TrainerAIPromptSection.swift draftCapsule: a dashed placeholder until a prompt is typed,
         * then the prompt itself. Tapping it adds the prompt, its thumbs down flips it between
         * focus and hidden, and its scope toggles pick where it will apply.
         */
        private fun bindPreviewRow() {
            binding.aiPreviewHolder.addView(
                preview,
                FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT),
            )
            preview.onDislike = {
                choosePreviewScore(if (previewScore == Classifier.DISLIKE) Classifier.LIKE else Classifier.DISLIKE)
            }
            preview.onScope = { scope ->
                scopePicker.request(scope) {
                    previewScope = it
                    refresh()
                }
            }
        }

        // A test result answers for one direction, so flipping it clears the result like editing does.
        private fun choosePreviewScore(score: Int) {
            if (score != previewScore) clearTestResults()
            previewScore = score
            refresh()
        }

        private fun renderPreviewRow() {
            val prompt = typedPrompt
            preview.onTap = if (prompt.isEmpty()) null else ({ addTypedPrompt() })
            preview.bind(
                TrainerCapsuleView.Model(
                    style = TrainerCapsuleView.Style.PROMPT,
                    level = if (prompt.isEmpty()) TrainerScores.Level.NEUTRAL else TrainerScores.level(previewScore),
                    label = typeLabel(),
                    value = prompt.ifEmpty { context.getString(R.string.ai_prompt_placeholder) },
                    showsDislike = prompt.isNotEmpty(),
                    isDraft = prompt.isNotEmpty(),
                    isPlaceholder = prompt.isEmpty(),
                    scope = if (prompt.isEmpty()) null else TrainerScopePicker.kind(previewScope),
                    isFolderAvailable = scopePicker.isFolderAvailable,
                ),
                trainerColors,
            )
        }

        private fun renderSavedList() {
            binding.aiSavedList.removeAllViews()
            for (prompt in scores.keys.toList()) {
                val capsule = TrainerCapsuleView(context)

                fun render() {
                    val score = scores[prompt]
                    val scope = classifier.promptScope(imagePrompt, prompt)
                    capsule.bind(
                        TrainerCapsuleView.Model(
                            style = TrainerCapsuleView.Style.PROMPT,
                            level = TrainerScores.level(score),
                            label = typeLabel(),
                            value = prompt,
                            showsDislike = true,
                            // A removed prompt stays listed, struck through, until the trainer saves.
                            isRemoved = TrainerScores.level(score) == TrainerScores.Level.NEUTRAL,
                            scope = TrainerScopePicker.kind(scope),
                            isFolderAvailable = scopePicker.isFolderAvailable,
                        ),
                        trainerColors,
                    )
                }

                // TrainerAIPromptSection.swift tap and tapDislike, through the same Classifier values
                // the old focus, hide and remove buttons stored.
                fun change(next: (current: Int?, original: Int?) -> Int?) {
                    val value = next(scores[prompt], originalScores[prompt])
                    TrainerScores.store(scores, prompt, value)
                    if (value == null) {
                        // A prompt added in this trainer and turned off again leaves nothing behind.
                        classifier.setPromptScope(imagePrompt, prompt, ClassifierScope.FEED_SCOPE)
                        renderSavedList()
                    } else {
                        render()
                    }
                    refresh()
                }
                capsule.onTap = { change { current, original -> TrainerScores.afterTap(TrainerScores.TapStyle.CYCLE, current, original) } }
                capsule.onDislike = { change(TrainerScores::afterDislike) }
                capsule.onScope = { scope ->
                    scopePicker.request(scope) {
                        classifier.setPromptScope(imagePrompt, prompt, it)
                        render()
                        refresh()
                    }
                }
                render()
                binding.aiSavedList.addView(
                    capsule,
                    LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                        topMargin = dp(6)
                    },
                )
            }
        }

        private val originalScores: Map<String, Int>
            get() = if (imagePrompt) original.imagePrompts else original.prompts

        private fun typeLabel(): String =
            context.getString(if (imagePrompt) R.string.ai_prompt_type_image else R.string.ai_prompt_type_content)

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
                frame.background = rounded(trainerColors.insetBackground, if (matched) colors.matchText else trainerColors.fieldBorder)
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
            // TrainerAIPromptSection.swift statusBadge is a capsule.
            binding.aiTestStatus.background = rounded(fill, border, radiusDp = 100)
            binding.aiTestStatus.isVisible = true
        }

        private fun clearTestResults() {
            binding.aiTestStatus.isVisible = false
            thumbs.forEach { (frame, label) ->
                frame.background = rounded(trainerColors.insetBackground, trainerColors.fieldBorder)
                label.isVisible = false
            }
        }
    }
}
