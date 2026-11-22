package com.newsblur.fragment

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.text.Editable
import android.text.TextWatcher
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
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.lifecycleScope
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.activity.AiCreditsActivity
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.IncludeAiClassifierSectionBinding
import com.newsblur.design.AiClassifierPalette
import com.newsblur.design.TrainerPalette
import com.newsblur.domain.Classifier
import com.newsblur.domain.ClassifierScope
import com.newsblur.domain.Story
import com.newsblur.network.ClassifierApi
import com.newsblur.network.PromptTestRequest
import com.newsblur.network.domain.AiClassifierUsageResponse
import com.newsblur.network.domain.AiCredits
import com.newsblur.network.domain.PromptTestResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.AiCreditsAction
import com.newsblur.util.AiCreditsNoticeStyle
import com.newsblur.util.AiCreditsStage
import com.newsblur.util.AiCreditsStatus
import com.newsblur.util.AiCreditsText
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import com.newsblur.view.TrainerCapsuleView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/**
 * The trainer's one AI filter card, like media/js/newsblur/reader/reader_classifier.js and
 * clients/ios/Classes/TrainerAIPromptSection.swift. A Text | Images switch picks what the filter
 * being written reads; Images mode shows the story's images, which carry each image's test
 * result. The typed prompt gets a capsule (view/TrainerCapsuleView.kt) once there's text, whose
 * thumbs down flips it between focus and hidden, and can be tested on the current story. Below
 * that, one line says what a filter of the selected kind uses on this site, or, for a free
 * account with an AI filter, which plans run it. Every saved AI filter on this site, text and
 * image, is listed together whichever mode is selected, and each toggles or gets removed in its
 * own list. At the bottom, a paid account's credits this month open the AI credits screen
 * (activity/AiCreditsActivity.kt), with at most one line about low credits, a pause or usage
 * billing (AiFilterAccess.kt, util/AiCreditsText.kt). The credits refresh whenever the trainer
 * comes back to the front, such as from the AI credits screen or Stripe.
 *
 * Prompt edits go straight into [classifier]: a prompt typed in Text mode is a text prompt, and
 * one typed in Images mode an image prompt sent with include_images. Call [commit] right before
 * the trainer saves, then Classifier.recordChanges, as IntelTrainerSections.kt does.
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
    private val binding = IncludeAiClassifierSectionBinding.inflate(LayoutInflater.from(context), container, false)
    private val colors = AiClassifierPalette.colors(theme)
    private val trainerColors = TrainerPalette.colors(theme)
    private val medium: Typeface? = ResourcesCompat.getFont(context, R.font.whitney_ssm_medium_bas)
    private val creditsText = AiCreditsText(context)
    private var credits: AiCredits? = prefsRepo.getAiCredits()

    // The site's estimates from /analyzer/ai_classifier_usage, once it answers.
    private var usage: AiClassifierUsageResponse? = null

    // Images mode: the typed prompt reads the story's images. Text mode is the default.
    private var imageMode = false
    private var previewScore = Classifier.LIKE
    private var previewScope = ClassifierScope.FEED_SCOPE
    private val imageUrls: List<String> = if (story != null) dbHelper.getStoryImageUrls(story.storyHash) else emptyList()
    private val thumbs = mutableListOf<Pair<FrameLayout, TextView>>()
    private val tester = AiPromptTester(fragment.lifecycleScope, classifierApi)
    private val preview = TrainerCapsuleView(context)

    private val typedPrompt: String
        get() =
            binding.aiPromptInput.text
                .toString()
                .trim()

    private val draft: AiPromptDraft
        get() = AiPromptDraft(typedPrompt, hidden = previewScore == Classifier.DISLIKE, imagePrompt = imageMode)

    private fun scores(imagePrompt: Boolean): LinkedHashMap<String, Int> = if (imagePrompt) classifier.imagePrompts else classifier.prompts

    private fun originalScores(imagePrompt: Boolean): Map<String, Int> = if (imagePrompt) original.imagePrompts else original.prompts

    fun bind() {
        container.addView(binding.root)
        // IntelTrainerSections.kt: the same header and card as the trainer's other sections.
        // The Text | Images switch ends where the card does.
        binding.aiSectionHeader.layoutParams = IntelTrainerSections.sectionHeaderParams(context).apply { marginEnd = dp(12) }
        binding.aiSectionCard.layoutParams = IntelTrainerSections.sectionCardParams(context)
        IntelTrainerSections.styleCard(binding.aiSectionCard, trainerColors)
        binding.aiSectionIcon.setImageResource(R.drawable.ic_ai_text_filter)
        binding.aiSectionIcon.imageTintList = ColorStateList.valueOf(trainerColors.promptAccent)
        binding.aiSectionTitle.setTextColor(trainerColors.textPrimary)
        binding.aiSectionTitle.typeface = medium

        bindModeSwitch()
        bindInput()
        bindImageGrid()
        bindPreview()
        bindCredits()
        renderMode()
        renderSavedList()
        render()

        // AiClassifierSections.kt rereads the credits each time the trainer is in front again, so
        // a change made on the AI credits screen, in Stripe or on the web shows on return.
        fragment.viewLifecycleOwner.lifecycle.addObserver(
            LifecycleEventObserver { _, event ->
                if (event == Lifecycle.Event.ON_RESUME) refreshCredits()
            },
        )
    }

    /** Keeps a typed but unadded prompt, since the web saves its live preview pill too. */
    fun commit() {
        if (typedPrompt.isNotEmpty()) addTypedPrompt()
    }

    private fun refreshCredits() {
        prefsRepo.getAiCredits()?.let { credits = it }
        render()
        val owner = fragment.viewLifecycleOwner
        owner.lifecycleScope.launch {
            val response = withContext(Dispatchers.IO) { classifierApi.getAiClassifierUsage(feedId) }
            if (!response.isSuccess) return@launch
            response.aiCredits?.let {
                credits = it
                prefsRepo.setAiCredits(it)
            }
            usage = response
            render()
        }
    }

    private fun openCredits(action: AiCreditsAction? = null) {
        if (action == AiCreditsAction.UPGRADE) {
            UIUtils.startSubscriptionActivity(context)
        } else {
            context.startActivity(AiCreditsActivity.intent(context, action))
        }
    }

    private fun status(): AiSectionStatus =
        AiFilterAccess.status(
            credits = credits,
            savedScores = scores(imagePrompt = false).values + scores(imagePrompt = true).values,
            typedPrompt = typedPrompt,
            hasStory = story != null,
            imagePrompt = imageMode,
            imageCount = imageUrls.size,
            isTesting = tester.isTesting,
        )

    // Mode switch

    private fun bindModeSwitch() {
        binding.aiModeSwitch.background = rounded(trainerColors.segmentTrack, radiusDp = 6)
        listOf(binding.aiModeText, binding.aiModeImages).forEach { it.typeface = medium }
        binding.aiModeText.setOnClickListener { setMode(image = false) }
        binding.aiModeImages.setOnClickListener { setMode(image = true) }
    }

    private fun setMode(image: Boolean) {
        if (image == imageMode) return
        imageMode = image
        // A test result answers for one kind of filter, so switching clears it like editing does.
        clearTestResults()
        renderMode()
        render()
    }

    /** What changes with the mode: the switch, the images, the placeholder and the Test button. */
    private fun renderMode() {
        styleSegment(binding.aiModeText, selected = !imageMode)
        styleSegment(binding.aiModeImages, selected = imageMode)
        binding.aiImageGridScroll.isVisible = imageMode && imageUrls.isNotEmpty()
        binding.aiPromptInput.setHint(if (imageMode) R.string.ai_image_prompt_hint else R.string.ai_text_prompt_hint)
        if (!tester.isTesting) binding.aiTestButton.setText(testLabel())
        binding.aiTestButton.isVisible = status().showsTestButton
    }

    private fun styleSegment(
        segment: TextView,
        selected: Boolean,
    ) {
        // TrainerPhraseInput.kt's Exact phrase | Regex segments.
        segment.background = if (selected) rounded(trainerColors.segmentSelected, radiusDp = 4) else null
        segment.setTextColor(if (selected) trainerColors.segmentSelectedText else trainerColors.segmentText)
        segment.isSelected = selected
    }

    // Compose area

    private fun bindInput() {
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
                    render()
                }
            },
        )
        // Like pressing Enter on the web, Done adds the typed prompt to the saved list.
        binding.aiPromptInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId != EditorInfo.IME_ACTION_DONE || typedPrompt.isEmpty()) return@setOnEditorActionListener false
            addTypedPrompt()
            true
        }
        styleButton(binding.aiTestButton)
        binding.aiTestButton.setOnClickListener { runTest() }
    }

    private fun addTypedPrompt() {
        AiFilterAccess.addDraft(classifier, draft, previewScope)
        binding.aiPromptInput.setText("")
        previewScore = Classifier.LIKE
        previewScope = ClassifierScope.FEED_SCOPE
        renderSavedList()
        render()
    }

    private fun render() {
        val status = status()
        renderPreview()
        binding.aiTestButton.isEnabled = status.testEnabled
        binding.aiTestButton.alpha = if (binding.aiTestButton.isEnabled) 1f else 0.5f
        renderEstimate(status)
        renderCredits(status)
    }

    private fun bindImageGrid() {
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

    /**
     * TrainerAIPromptSection.swift draftCapsule, shown once a prompt is typed. Tapping it adds the
     * prompt, its thumbs down flips it between focus and hidden, and its scope toggles pick where
     * it will apply.
     */
    private fun bindPreview() {
        binding.aiPreviewHolder.addView(
            preview,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        preview.onTap = { if (typedPrompt.isNotEmpty()) addTypedPrompt() }
        preview.onDislike = {
            choosePreviewScore(if (previewScore == Classifier.DISLIKE) Classifier.LIKE else Classifier.DISLIKE)
        }
        preview.onScope = { scope ->
            scopePicker.request(scope) {
                previewScope = it
                render()
            }
        }
    }

    // A test result answers for one direction, so flipping it clears the result like editing does.
    private fun choosePreviewScore(score: Int) {
        if (score != previewScore) clearTestResults()
        previewScore = score
        render()
    }

    private fun renderPreview() {
        val prompt = typedPrompt
        binding.aiPreviewHolder.isVisible = prompt.isNotEmpty()
        if (prompt.isEmpty()) return
        preview.bind(
            TrainerCapsuleView.Model(
                style = TrainerCapsuleView.Style.PROMPT,
                level = TrainerScores.level(previewScore),
                label = typeLabel(imageMode),
                value = prompt,
                showsDislike = true,
                isDraft = true,
                scope = TrainerScopePicker.kind(previewScope),
                isFolderAvailable = scopePicker.isFolderAvailable,
            ),
            trainerColors,
        )
    }

    /** The selected mode's per-site estimate, or a free account's plans in its place. */
    private fun renderEstimate(status: AiSectionStatus) {
        val credits = credits
        val free = status.creditsStage == AiCreditsStage.FREE
        binding.aiUpgradeNotice.isVisible = free
        val perMonth = usage?.let { if (imageMode) it.imageCreditsPerMonth else it.textCreditsPerMonth }
        val estimate =
            perMonth
                ?.takeIf { credits != null && AiCreditsStatus.isRunning(credits) }
                ?.let { creditsText.estimate(it, imageMode) }
        binding.aiCreditsEstimate.text = estimate
        binding.aiCreditsEstimate.isVisible = estimate != null && !free
    }

    // Saved filters

    /** Every AI filter on this site in one list, text first, each kind in its own classifier list. */
    private fun renderSavedList() {
        binding.aiSavedList.removeAllViews()
        for (imagePrompt in listOf(false, true)) {
            for (prompt in scores(imagePrompt).keys.toList()) {
                binding.aiSavedList.addView(
                    savedCapsule(imagePrompt, prompt),
                    LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                        topMargin = dp(6)
                    },
                )
            }
        }
    }

    private fun savedCapsule(
        imagePrompt: Boolean,
        prompt: String,
    ): TrainerCapsuleView {
        val scores = scores(imagePrompt)
        val capsule = TrainerCapsuleView(context)

        fun bindCapsule() {
            val score = scores[prompt]
            capsule.bind(
                TrainerCapsuleView.Model(
                    style = TrainerCapsuleView.Style.PROMPT,
                    level = TrainerScores.level(score),
                    label = typeLabel(imagePrompt),
                    value = prompt,
                    showsDislike = true,
                    // A removed prompt stays listed, struck through, until the trainer saves.
                    isRemoved = TrainerScores.level(score) == TrainerScores.Level.NEUTRAL,
                    scope = TrainerScopePicker.kind(classifier.promptScope(imagePrompt, prompt)),
                    isFolderAvailable = scopePicker.isFolderAvailable,
                ),
                trainerColors,
            )
        }

        // TrainerAIPromptSection.swift tap and tapDislike, through the same Classifier values
        // the old focus, hide and remove buttons stored.
        fun change(next: (current: Int?, original: Int?) -> Int?) {
            val value = next(scores[prompt], originalScores(imagePrompt)[prompt])
            TrainerScores.store(scores, prompt, value)
            if (value == null) {
                // A prompt added in this trainer and turned off again leaves nothing behind.
                classifier.setPromptScope(imagePrompt, prompt, ClassifierScope.FEED_SCOPE)
                renderSavedList()
            } else {
                bindCapsule()
            }
            render()
        }
        capsule.onTap = { change { current, original -> TrainerScores.afterTap(TrainerScores.TapStyle.CYCLE, current, original) } }
        capsule.onDislike = { change(TrainerScores::afterDislike) }
        capsule.onScope = { scope ->
            scopePicker.request(scope) {
                classifier.setPromptScope(imagePrompt, prompt, it)
                bindCapsule()
                render()
            }
        }
        bindCapsule()
        return capsule
    }

    private fun typeLabel(imagePrompt: Boolean): String =
        context.getString(if (imagePrompt) R.string.ai_prompt_type_image else R.string.ai_prompt_type_content)

    // Credits

    /** The credits line opens the AI credits screen; the state line's button goes where its state leads. */
    private fun bindCredits() {
        binding.aiCreditsUsed.setTextColor(trainerColors.textPrimary)
        binding.aiCreditsUsed.typeface = medium
        binding.aiCreditsChevron.imageTintList = ColorStateList.valueOf(trainerColors.textSecondary)
        binding.aiCreditsChevron.drawable?.isAutoMirrored = true
        binding.aiCreditsEstimate.setTextColor(trainerColors.textSecondary)
        binding.aiCreditsMeter.background =
            RippleDrawable(ColorStateList.valueOf(colors.badgeBackground), null, rounded(colors.badgeBackground))
        binding.aiCreditsMeter.contentDescription = context.getString(R.string.ai_credits_open)
        binding.aiCreditsMeter.setOnClickListener { openCredits() }
        styleButton(binding.aiCreditsAction)

        binding.aiUpgradeNotice.background = rounded(colors.upgradeBackground, colors.upgradeBorder, radiusDp = 8)
        binding.aiUpgradeMessage.setTextColor(colors.upgradeText)
        binding.aiUpgradeMessage.typeface = medium
        binding.aiUpgradeMessage.text = creditsText.free()
        styleButton(binding.aiUpgradeAction)
        binding.aiUpgradeAction.setOnClickListener { openCredits(AiCreditsAction.UPGRADE) }
    }

    private fun renderCredits(status: AiSectionStatus) {
        val credits = credits
        val stage = status.creditsStage
        val showsMeter = credits != null && AiCreditsStatus.showsMeter(credits)
        // The paused, low and usage billing statement as one plain line, without its explanation
        // or a second line, which the AI credits screen has room for.
        val notice = credits?.takeIf { stage != AiCreditsStage.FREE && stage != AiCreditsStage.HIDDEN }?.let { creditsText.notice(it) }
        binding.aiCreditsRow.isVisible = credits != null && (showsMeter || notice != null)
        if (credits == null) return

        binding.aiCreditsMeter.isVisible = showsMeter
        binding.aiCreditsBar.isVisible = showsMeter
        if (showsMeter) {
            binding.aiCreditsUsed.text = creditsText.meter(credits)
            binding.aiCreditsBar.bind(credits, colors)
        }

        binding.aiCreditsState.isVisible = notice != null
        binding.aiCreditsAction.isVisible = notice?.action != null && notice.actionLabel != null
        if (notice == null) return
        binding.aiCreditsState.text = notice.message
        binding.aiCreditsState.setTextColor(
            when (notice.style) {
                AiCreditsNoticeStyle.WARNING -> colors.warningText
                AiCreditsNoticeStyle.PAUSED -> colors.pausedText
                AiCreditsNoticeStyle.BILLING, AiCreditsNoticeStyle.UPGRADE -> trainerColors.textSecondary
            },
        )
        binding.aiCreditsAction.text = notice.actionLabel
        binding.aiCreditsAction.setOnClickListener { openCredits(notice.action) }
    }

    // Testing

    private fun testLabel(): Int =
        when {
            !imageMode -> R.string.ai_test_story
            imageUrls.size == 1 -> R.string.ai_test_image
            else -> R.string.ai_test_images
        }

    private fun runTest() {
        val tested = draft
        val storyHash = story?.storyHash ?: return
        if (tested.prompt.isEmpty() || tester.isTesting) return
        clearTestResults()
        binding.aiTestButton.setText(if (tested.imagePrompt) R.string.ai_analyzing_images else R.string.ai_testing_story)
        if (tested.imagePrompt) thumbs.forEach { (frame, _) -> frame.alpha = 0.5f }
        val request = PromptTestRequest(tested.prompt, storyHash, feedId, includeImages = tested.imagePrompt, hidden = tested.hidden)
        tester.run(request, currentDraft = { draft }) { response, isCurrent ->
            if (!fragment.isAdded) return@run
            binding.aiTestButton.setText(testLabel())
            thumbs.forEach { (frame, _) -> frame.alpha = 1f }
            // AiClassifierSections.kt drops a result for a draft that changed mid-test, such as
            // its text, direction or mode, so an untested prompt never looks verified.
            if (isCurrent) showTestResult(response)
            render()
        }
        render()
    }

    private fun showTestResult(response: PromptTestResponse) {
        if (!response.isSuccess) {
            val message = response.message ?: context.getString(R.string.ai_test_failed)
            showStatus(message, colors.errorBackground, colors.errorText, colors.errorBorder)
            return
        }
        if (!imageMode) {
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

    private fun styleButton(button: MaterialButton) {
        button.backgroundTintList = ColorStateList.valueOf(colors.accent)
        button.setTextColor(colors.accentText)
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
}
