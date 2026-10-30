package com.newsblur.fragment

import android.app.Dialog
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.res.ResourcesCompat
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.newsblur.R
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.databinding.FragmentIntelTrainerSheetBinding
import com.newsblur.design.AiClassifierPalette
import com.newsblur.design.TrainerPalette
import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import com.newsblur.fragment.TrainerScores.TapStyle
import com.newsblur.network.ClassifierApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import com.newsblur.view.TrainerCapsuleView
import com.newsblur.view.TrainerFlowLayout
import java.util.IdentityHashMap
import kotlin.math.roundToInt

/**
 * The body of the story trainer (StoryIntelTrainerFragment.java) and the site trainer
 * (FeedIntelTrainerFragment.java), laid out like clients/ios/Classes/TrainerView.swift: a header
 * and a rounded card per section, with the story title's words, classifier capsules
 * (view/TrainerCapsuleView.kt) and a phrase box (TrainerPhraseInput.kt) in each, then the
 * natural language sections (AiClassifierSections.kt) and the publisher.
 *
 * Every change goes straight into [classifier], as the old rows did. Call [commit] right before
 * the trainer saves.
 */
class IntelTrainerSections(
    private val fragment: Fragment,
    private val container: LinearLayout,
    private val classifier: Classifier,
    // Null in the site trainer.
    private val story: Story?,
    private val feedId: String,
    private val theme: ThemeValue,
    private val prefsRepo: PrefsRepo,
    private val dbHelper: BlurDatabaseHelper,
    private val classifierApi: ClassifierApi,
    private val thumbnailLoader: ImageLoader,
    private val iconLoader: ImageLoader,
) {
    private val context: Context = fragment.requireContext()
    private val colors = TrainerPalette.colors(theme)
    private val density = context.resources.displayMetrics.density
    private val medium: Typeface? = ResourcesCompat.getFont(context, R.font.whitney_ssm_medium_bas)
    private val isStoryTrainer = story != null
    private val feed = dbHelper.getFeed(feedId)
    private val originalRegexes = classifier.copyRegexes()

    // The scores the trainer opened with, so a capsule set back to neutral removes a saved opinion
    // or restores an untrained one, see TrainerScores.neutral.
    private val originals =
        IdentityHashMap<Map<String, Int>, Map<String, Int>>().apply {
            listOf(
                classifier.title,
                classifier.titleRegex,
                classifier.authors,
                classifier.authorRegex,
                classifier.tags,
                classifier.texts,
                classifier.textRegex,
                classifier.urls,
                classifier.urlRegex,
                classifier.feeds,
            ).forEach { put(it, LinkedHashMap(it)) }
        }
    private lateinit var aiSections: AiClassifierSections

    fun bind() {
        addPhraseSection(TrainerPhraseKind.TITLE)
        addPhraseSection(TrainerPhraseKind.AUTHOR)
        addTagSection()
        addPhraseSection(TrainerPhraseKind.TEXT)
        addPhraseSection(TrainerPhraseKind.URL)
        val aiContainer = LinearLayout(context)
        aiContainer.orientation = LinearLayout.VERTICAL
        container.addView(aiContainer)
        aiSections = AiClassifierSections(fragment, aiContainer, classifier, story, feedId, theme, prefsRepo, dbHelper, classifierApi, thumbnailLoader)
        aiSections.bind()
        addPublisherSection()
    }

    /** Records the regex changes and the AI prompt changes that need their own save requests. */
    fun commit() {
        classifier.recordRegexChanges(originalRegexes)
        aiSections.commit()
    }

    private fun originalOf(scores: Map<String, Int>): Map<String, Int> = originals[scores].orEmpty()

    // Sections

    private fun addPhraseSection(kind: TrainerPhraseKind) {
        val card = addSection(context.getString(sectionTitle(kind)))
        val phrases = LinkedHashSet(shownPhrases(kind))
        val regexes = LinkedHashSet(shownRegexes(kind))
        val capsules = flow()

        fun render() {
            capsules.removeAllViews()
            val label = context.getString(phraseLabel(kind))
            phrases.forEach { phrase ->
                capsules.addView(capsule(kind.phrases(classifier), phrase, TrainerCapsuleView.Style.PHRASE, label, phraseTapStyle(kind)))
            }
            regexes.forEach { regex ->
                capsules.addView(capsule(kind.regexes(classifier), regex, TrainerCapsuleView.Style.REGEX, label, TapStyle.TOGGLE_LIKE))
            }
            capsules.isVisible = capsules.childCount > 0
        }

        fun add(
            pattern: String,
            isRegex: Boolean,
            change: (current: Int?, original: Int?) -> Int?,
        ) {
            val scores = if (isRegex) kind.regexes(classifier) else kind.phrases(classifier)
            TrainerScores.store(scores, pattern, change(scores[pattern], originalOf(scores)[pattern]))
            (if (isRegex) regexes else phrases).add(pattern)
            render()
        }

        val story = story
        if (kind == TrainerPhraseKind.TITLE && story != null) {
            addTitleWords(card, story) { phrase, change -> add(phrase, false, change) }
        }
        card.addView(capsules, matchWidth(topMargin = dp(6)))
        val input = TrainerPhraseInput(context, kind, story, colors, prefsRepo.getIsPro(), ::add)
        card.addView(input.view, matchWidth())
        render()
    }

    /**
     * TrainerView.swift's "Choose one or more words from the title:" chips. Tapped words build a
     * phrase shown as a capsule, and tapping that capsule adds it to the title classifiers.
     */
    private fun addTitleWords(
        card: LinearLayout,
        story: Story,
        onAdd: (String, (current: Int?, original: Int?) -> Int?) -> Unit,
    ) {
        card.addView(
            TextView(context).apply {
                setText(R.string.trainer_choose_title_words)
                typeface = medium
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setTextColor(colors.textSecondary)
            },
            matchWidth(topMargin = dp(4)),
        )
        val words = flow(horizontal = dp(3), vertical = dp(6))
        card.addView(words, matchWidth(topMargin = dp(10)))

        var phrase = ""
        // TrainerView.swift: the phrase's capsule with a clear button beside it. The row wraps its
        // content, and a long phrase's capsule shrinks to keep the button on screen.
        val addingRow = LinearLayout(context)
        addingRow.orientation = LinearLayout.HORIZONTAL
        addingRow.gravity = Gravity.CENTER_VERTICAL
        val adding = TrainerCapsuleView(context)
        addingRow.addView(adding, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { weight = 1f })
        val clear = clearButton()
        addingRow.addView(clear, LinearLayout.LayoutParams(dp(38), dp(38)).apply { marginStart = dp(4) })
        card.addView(addingRow, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(10) })

        fun renderAdding() {
            addingRow.isVisible = phrase.isNotEmpty()
            if (phrase.isEmpty()) return
            adding.bind(
                TrainerCapsuleView.Model(
                    style = TrainerCapsuleView.Style.PHRASE,
                    level = TrainerScores.Level.NEUTRAL,
                    label = context.getString(R.string.trainer_label_title),
                    value = phrase,
                    showsDislike = true,
                    showsSuperDislike = true,
                ),
                colors,
            )
        }

        fun addPhrase(change: (current: Int?, original: Int?) -> Int?) {
            if (phrase.isEmpty()) return
            onAdd(phrase, change)
            phrase = ""
            renderAdding()
        }
        adding.onTap = { addPhrase { current, original -> TrainerScores.afterTap(TapStyle.TOGGLE_LIKE, current, original) } }
        adding.onDislike = { addPhrase(TrainerScores::afterDislike) }
        adding.onSuperDislike = { addPhrase(TrainerScores::afterSuperDislike) }
        clear.setOnClickListener {
            phrase = ""
            renderAdding()
        }

        TrainerPhrase.words(story.title).forEach { word ->
            words.addView(
                TextView(context).apply {
                    text = word
                    typeface = medium
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                    setTextColor(colors.wordText)
                    setPadding(dp(5), dp(3), dp(5), dp(3))
                    background = rounded(colors.wordBackground, dp(5).toFloat())
                    setOnClickListener {
                        phrase = TrainerPhrase.appendWord(phrase, word)
                        renderAdding()
                    }
                },
            )
        }
        renderAdding()
    }

    private fun addTagSection() {
        val tags =
            if (story != null) {
                story.tags?.toList().orEmpty()
            } else {
                // The site's recent tags, then any trained tag they don't include.
                dbHelper.getTagsForFeed(feedId) + classifier.tags.keys
            }.distinct()
        if (tags.isEmpty()) return
        val card = addSection(context.getString(if (isStoryTrainer) R.string.trainer_section_story_tags else R.string.trainer_section_tags))
        val capsules = flow()
        val label = context.getString(R.string.trainer_label_tag)
        tags.forEach { tag -> capsules.addView(capsule(classifier.tags, tag, TrainerCapsuleView.Style.PHRASE, label, TapStyle.CYCLE)) }
        card.addView(capsules, matchWidth(topMargin = dp(4)))
    }

    /** TrainerView.swift's "Everything by This Publisher": a Site capsule with the favicon. */
    private fun addPublisherSection() {
        val card = addSection(context.getString(R.string.trainer_section_publisher))
        val capsule =
            capsule(
                classifier.feeds,
                feedId,
                TrainerCapsuleView.Style.PHRASE,
                context.getString(R.string.trainer_label_site),
                TapStyle.CYCLE,
                value = feed?.title.orEmpty(),
                faviconUrl = feed?.faviconUrl,
            )
        card.addView(capsule, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(4) })
    }

    // Which classifiers each section lists

    /**
     * The story trainer lists the saved phrases this story matches, as TrainerView.swift does with
     * the story's own classifiers. The site trainer lists them all.
     */
    private fun shownPhrases(kind: TrainerPhraseKind): List<String> {
        val saved = kind.phrases(classifier).keys
        val story = story ?: return if (kind == TrainerPhraseKind.AUTHOR) (dbHelper.getAuthorsForFeed(feedId) + saved).distinct() else saved.toList()
        return when (kind) {
            // A story has a single author, trained or not.
            TrainerPhraseKind.AUTHOR -> listOfNotNull(story.authors?.takeIf { it.isNotBlank() })
            else -> saved.filter { TrainerPhrase.phraseMatches(it, storyText(kind, story)) }
        }
    }

    private fun shownRegexes(kind: TrainerPhraseKind): List<String> {
        val saved = kind.regexes(classifier).keys
        val story = story ?: return saved.toList()
        return saved.filter { TrainerPhrase.regexMatches(it, storyText(kind, story)) == true }
    }

    private fun storyText(
        kind: TrainerPhraseKind,
        story: Story,
    ): String? =
        when (kind) {
            TrainerPhraseKind.TITLE -> story.title
            TrainerPhraseKind.AUTHOR -> story.authors
            TrainerPhraseKind.TEXT -> story.content
            TrainerPhraseKind.URL -> story.permalink
        }

    private fun sectionTitle(kind: TrainerPhraseKind): Int =
        when (kind) {
            TrainerPhraseKind.TITLE -> if (isStoryTrainer) R.string.trainer_section_story_title else R.string.trainer_section_titles
            TrainerPhraseKind.AUTHOR -> if (isStoryTrainer) R.string.trainer_section_story_author else R.string.trainer_section_authors
            TrainerPhraseKind.TEXT -> if (isStoryTrainer) R.string.trainer_section_story_text else R.string.trainer_section_texts
            TrainerPhraseKind.URL -> if (isStoryTrainer) R.string.trainer_section_story_url else R.string.trainer_section_urls
        }

    private fun phraseLabel(kind: TrainerPhraseKind): Int =
        when (kind) {
            TrainerPhraseKind.TITLE -> R.string.trainer_label_title
            TrainerPhraseKind.AUTHOR -> R.string.trainer_label_author
            TrainerPhraseKind.TEXT -> R.string.trainer_label_text
            TrainerPhraseKind.URL -> R.string.trainer_label_url
        }

    /** NewsBlurAppDelegate.m: authors cycle through a dislike, titles, text and URLs toggle a like. */
    private fun phraseTapStyle(kind: TrainerPhraseKind): TapStyle = if (kind == TrainerPhraseKind.AUTHOR) TapStyle.CYCLE else TapStyle.TOGGLE_LIKE

    // Views

    /** One classifier's capsule, which rebinds itself as the reader taps it. */
    private fun capsule(
        scores: MutableMap<String, Int>,
        key: String,
        style: TrainerCapsuleView.Style,
        label: String,
        tapStyle: TapStyle,
        value: String = key,
        faviconUrl: String? = null,
    ): TrainerCapsuleView {
        val capsule = TrainerCapsuleView(context)
        if (faviconUrl != null) {
            capsule.favicon.isVisible = true
            iconLoader.displayImage(faviconUrl, capsule.favicon)
        }

        fun render() {
            capsule.bind(
                TrainerCapsuleView.Model(
                    style = style,
                    level = TrainerScores.level(scores[key]),
                    label = label,
                    value = value,
                    showsDislike = true,
                    showsSuperDislike = true,
                ),
                colors,
            )
        }

        fun change(next: (current: Int?, original: Int?) -> Int?) {
            TrainerScores.store(scores, key, next(scores[key], originalOf(scores)[key]))
            render()
        }
        capsule.onTap = { change { current, original -> TrainerScores.afterTap(tapStyle, current, original) } }
        capsule.onDislike = { change(TrainerScores::afterDislike) }
        capsule.onSuperDislike = { change(TrainerScores::afterSuperDislike) }
        render()
        return capsule
    }

    private fun addSection(title: String): LinearLayout {
        container.addView(sectionHeader(context, colors, title), sectionHeaderParams(context))
        val card = sectionCard(context, colors)
        container.addView(card, sectionCardParams(context))
        return card
    }

    private fun flow(
        horizontal: Int = dp(6),
        vertical: Int = dp(8),
    ) = TrainerFlowLayout(context).apply {
        horizontalSpacing = horizontal
        verticalSpacing = vertical
    }

    private fun clearButton() =
        ImageView(context).apply {
            setImageResource(R.drawable.ic_trainer_clear)
            imageTintList = ColorStateList.valueOf(colors.clearIcon)
            contentDescription = context.getString(R.string.trainer_clear_phrase)
            setPadding(dp(7), dp(7), dp(7), dp(7))
        }

    private fun matchWidth(topMargin: Int = 0) =
        LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            this.topMargin = topMargin
        }

    private fun rounded(
        fill: Int,
        radius: Float,
    ) = GradientDrawable().apply {
        cornerRadius = radius
        setColor(fill)
    }

    private fun dp(value: Int): Int = (value * density).roundToInt()

    companion object {
        /** TrainerView.swift header(): a section title above its card, inset to the card's content. */
        @JvmStatic
        fun sectionHeader(
            context: Context,
            colors: TrainerPalette.Colors,
            title: String,
        ): TextView =
            TextView(context).apply {
                text = title
                typeface = ResourcesCompat.getFont(context, R.font.whitney_ssm_medium_bas)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
                setTextColor(colors.textPrimary)
            }

        @JvmStatic
        fun sectionHeaderParams(context: Context): LinearLayout.LayoutParams {
            val density = context.resources.displayMetrics.density
            return LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                marginStart = (32 * density).roundToInt()
                marginEnd = (8 * density).roundToInt()
                topMargin = (24 * density).roundToInt()
                bottomMargin = (8 * density).roundToInt()
            }
        }

        /** TrainerView.swift's inset grouped rows: a rounded card on the sheet's background. */
        @JvmStatic
        fun sectionCard(
            context: Context,
            colors: TrainerPalette.Colors,
        ): LinearLayout =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                styleCard(this, colors)
            }

        @JvmStatic
        fun styleCard(
            card: View,
            colors: TrainerPalette.Colors,
        ) {
            val density = card.resources.displayMetrics.density
            val horizontal = (16 * density).roundToInt()
            card.setPadding(horizontal, (12 * density).roundToInt(), horizontal, (16 * density).roundToInt())
            card.background =
                GradientDrawable().apply {
                    cornerRadius = 20 * density
                    setColor(colors.cardBackground)
                }
        }

        @JvmStatic
        fun sectionCardParams(context: Context): LinearLayout.LayoutParams {
            val margin = (16 * context.resources.displayMetrics.density).roundToInt()
            return LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                marginStart = margin
                marginEnd = margin
            }
        }

        /**
         * TrainerView.swift trainerQuestion: the whole question is translated, then the inserted
         * "like" and "dislike" are colored wherever the language places them.
         */
        @JvmStatic
        fun question(
            context: Context,
            isStoryTrainer: Boolean,
            colors: TrainerPalette.Colors,
        ): CharSequence {
            val likeMarker = ""
            val dislikeMarker = ""
            val template = if (isStoryTrainer) R.string.trainer_question_story else R.string.trainer_question_site
            val question = SpannableStringBuilder(context.getString(template, likeMarker, dislikeMarker))
            listOf(
                Triple(likeMarker, R.string.trainer_question_like, colors.questionLike),
                Triple(dislikeMarker, R.string.trainer_question_dislike, colors.questionDislike),
            ).forEach { (marker, word, color) ->
                val start = question.indexOf(marker)
                if (start < 0) return@forEach
                val text = context.getString(word)
                question.replace(start, start + marker.length, text)
                question.setSpan(ForegroundColorSpan(color), start, start + text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            return question
        }

        /** Colors the sheet around the trainer: the question, legend, buttons and background. */
        @JvmStatic
        fun styleSheet(
            binding: FragmentIntelTrainerSheetBinding,
            theme: ThemeValue,
            isStoryTrainer: Boolean,
        ) {
            val context = binding.root.context
            val colors = TrainerPalette.colors(theme)
            val density = context.resources.displayMetrics.density
            binding.root.setBackgroundColor(colors.sheetBackground)
            binding.sheetDragHandle.background =
                GradientDrawable().apply {
                    cornerRadius = 2 * density
                    setColor(colors.dragHandle)
                }
            binding.sheetTitle.text = question(context, isStoryTrainer, colors)
            binding.sheetTitle.setTextColor(colors.textPrimary)
            binding.sheetTitle.typeface = ResourcesCompat.getFont(context, R.font.whitney_ssm_medium_bas)
            binding.cancelButton.setTextColor(colors.textSecondary)
            binding.cancelButton.rippleColor = ColorStateList.valueOf(colors.capsuleNeutral)
            val accent = AiClassifierPalette.colors(theme)
            binding.saveButton.backgroundTintList = ColorStateList.valueOf(accent.accent)
            binding.saveButton.setTextColor(accent.accentText)
            UIUtils.setupIntelExplainer(binding.root, theme)
        }

        /** Expands the trainer's bottom sheet on its background, with rounded top corners like an iOS sheet. */
        @JvmStatic
        fun expandSheet(
            dialog: Dialog,
            theme: ThemeValue,
        ) {
            val sheetDialog = dialog as? BottomSheetDialog ?: return
            val sheet = sheetDialog.findViewById<FrameLayout>(com.google.android.material.R.id.design_bottom_sheet) ?: return
            val radius = 16 * dialog.context.resources.displayMetrics.density
            sheet.background =
                GradientDrawable().apply {
                    cornerRadii = floatArrayOf(radius, radius, radius, radius, 0f, 0f, 0f, 0f)
                    setColor(TrainerPalette.colors(theme).sheetBackground)
                }
            sheet.clipToOutline = true
            sheetDialog.behavior.state = BottomSheetBehavior.STATE_EXPANDED
        }
    }
}
