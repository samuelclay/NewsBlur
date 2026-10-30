package com.newsblur.fragment

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.GridLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.ColorUtils
import androidx.core.view.isVisible
import com.newsblur.R
import com.newsblur.design.TrainerPalette
import com.newsblur.domain.Story
import com.newsblur.fragment.TrainerScores.TapStyle
import com.newsblur.view.TrainerCapsuleView
import com.newsblur.view.TrainerFlowLayout
import kotlin.math.roundToInt

/**
 * The phrase box at the bottom of a trainer section, ported from
 * clients/ios/Classes/TrainerRegexInput.swift: an Exact phrase | Regex segmented control, a
 * rounded text field, regex validation badges and a capsule previewing the classifier. Tapping the
 * capsule (or its inline dislike buttons) hands the phrase to [onAdd] and clears the field.
 */
class TrainerPhraseInput(
    private val context: Context,
    private val kind: TrainerPhraseKind,
    // Null in the site trainer, which has no story to match a regex against.
    private val story: Story?,
    private val colors: TrainerPalette.Colors,
    // reader_classifier.js: regex classifiers need Premium Pro, and apps/analyzer/models.py only scores them for Pro.
    private val canUseRegex: Boolean,
    private val onAdd: (pattern: String, isRegex: Boolean, change: (current: Int?, original: Int?) -> Int?) -> Unit,
) {
    private val density = context.resources.displayMetrics.density
    private val medium: Typeface? = ResourcesCompat.getFont(context, R.font.whitney_ssm_medium_bas)

    val view = LinearLayout(context)
    private val exactSegment = TextView(context)
    private val regexSegment = TextView(context)
    private val helpButton = ImageView(context)
    private val textField = EditText(context)
    private val clearButton = ImageView(context)
    private val badges = TrainerFlowLayout(context)
    private val draft = TrainerCapsuleView(context)
    private var isRegex = false

    private val pattern: String
        get() = textField.text.toString().trim()

    init {
        view.orientation = LinearLayout.VERTICAL
        view.setPadding(0, dp(12), 0, dp(4))

        val toggleRow = LinearLayout(context)
        toggleRow.orientation = LinearLayout.HORIZONTAL
        toggleRow.gravity = Gravity.CENTER_VERTICAL
        val track = LinearLayout(context)
        track.orientation = LinearLayout.HORIZONTAL
        track.setPadding(dp(2), dp(2), dp(2), dp(2))
        track.background = rounded(colors.segmentTrack, dp(6).toFloat())
        listOf(exactSegment to R.string.trainer_exact_phrase, regexSegment to R.string.trainer_regex).forEach { (segment, text) ->
            segment.setText(text)
            segment.typeface = medium
            segment.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            segment.setPadding(dp(14), dp(6), dp(14), dp(6))
            segment.gravity = Gravity.CENTER
            track.addView(segment)
        }
        exactSegment.setOnClickListener { setRegex(false) }
        regexSegment.setOnClickListener {
            if (!canUseRegex) {
                Toast.makeText(context, R.string.trainer_regex_requires_pro, Toast.LENGTH_SHORT).show()
            } else {
                setRegex(true)
            }
        }
        toggleRow.addView(track)
        helpButton.setImageResource(R.drawable.ic_trainer_info)
        helpButton.imageTintList = ColorStateList.valueOf(colors.regexAccent)
        helpButton.contentDescription = context.getString(R.string.trainer_regex_help)
        helpButton.setPadding(dp(8), dp(8), dp(8), dp(8))
        helpButton.setOnClickListener { showHelp() }
        toggleRow.addView(helpButton, LinearLayout.LayoutParams(dp(38), dp(38)).apply { marginStart = dp(4) })
        view.addView(toggleRow)

        val fieldRow = LinearLayout(context)
        fieldRow.orientation = LinearLayout.HORIZONTAL
        fieldRow.gravity = Gravity.CENTER_VERTICAL
        textField.background = rounded(colors.fieldBackground, dp(6).toFloat(), colors.fieldBorder)
        textField.setPadding(dp(10), dp(9), dp(10), dp(9))
        textField.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        textField.setTextColor(colors.textPrimary)
        textField.setHintTextColor(colors.textSecondary)
        textField.isSingleLine = true
        textField.imeOptions = EditorInfo.IME_ACTION_DONE
        textField.importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO
        // TrainerRegexInput.swift turns off autocorrection and capitalization.
        textField.inputType =
            InputType.TYPE_CLASS_TEXT or
            InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS or
            if (kind == TrainerPhraseKind.URL) InputType.TYPE_TEXT_VARIATION_URI else 0
        textField.addTextChangedListener(
            object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit

                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit

                override fun afterTextChanged(s: Editable?) = render()
            },
        )
        fieldRow.addView(textField, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT).apply { weight = 1f })
        clearButton.setImageResource(R.drawable.ic_trainer_clear)
        clearButton.imageTintList = ColorStateList.valueOf(colors.clearIcon)
        clearButton.contentDescription = context.getString(R.string.trainer_clear_phrase)
        clearButton.setPadding(dp(7), dp(7), dp(7), dp(7))
        clearButton.setOnClickListener { textField.setText("") }
        fieldRow.addView(clearButton, LinearLayout.LayoutParams(dp(38), dp(38)).apply { marginStart = dp(4) })
        view.addView(fieldRow, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) })

        badges.horizontalSpacing = dp(6)
        badges.verticalSpacing = dp(6)
        view.addView(badges, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) })

        draft.onTap = { add { current, original -> TrainerScores.afterTap(tapStyle(), current, original) } }
        draft.onDislike = { add(TrainerScores::afterDislike) }
        draft.onSuperDislike = { add(TrainerScores::afterSuperDislike) }
        view.addView(draft, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) })

        render()
    }

    private fun setRegex(regex: Boolean) {
        isRegex = regex
        render()
    }

    /** NewsBlurAppDelegate.m: a new author cycles like an author capsule, the rest toggle a like. */
    private fun tapStyle(): TapStyle = if (kind == TrainerPhraseKind.AUTHOR && !isRegex) TapStyle.CYCLE else TapStyle.TOGGLE_LIKE

    private fun add(change: (current: Int?, original: Int?) -> Int?) {
        val pattern = pattern
        if (pattern.isEmpty()) return
        // TrainerRegexInput.swift saveClassifier never saves an invalid regex.
        if (isRegex && TrainerPhrase.checkRegex(pattern) != TrainerPhrase.RegexCheck.Valid) return
        onAdd(pattern, isRegex, change)
        textField.setText("")
    }

    private fun render() {
        styleSegment(exactSegment, selected = !isRegex, selectedFill = colors.segmentSelected, selectedText = colors.segmentSelectedText)
        styleSegment(regexSegment, selected = isRegex, selectedFill = colors.regexAccent, selectedText = colors.capsuleActiveText)
        helpButton.isVisible = isRegex
        textField.typeface = if (isRegex) Typeface.MONOSPACE else medium
        textField.hint = placeholder()
        val pattern = pattern
        clearButton.visibility = if (textField.text.isNotEmpty()) View.VISIBLE else View.INVISIBLE
        renderBadges(pattern)
        draft.isVisible = pattern.isNotEmpty()
        if (pattern.isEmpty()) return
        val isValid = !isRegex || TrainerPhrase.checkRegex(pattern) == TrainerPhrase.RegexCheck.Valid
        draft.bind(
            TrainerCapsuleView.Model(
                style = if (isRegex) TrainerCapsuleView.Style.REGEX else TrainerCapsuleView.Style.PHRASE,
                level = TrainerScores.Level.NEUTRAL,
                label = context.getString(label()),
                value = pattern,
                showsDislike = true,
                showsSuperDislike = true,
            ),
            colors,
        )
        draft.alpha = if (isValid) 1f else 0.5f
    }

    private fun renderBadges(pattern: String) {
        badges.removeAllViews()
        badges.isVisible = isRegex && pattern.isNotEmpty()
        if (!badges.isVisible) return
        when (val check = TrainerPhrase.checkRegex(pattern)) {
            TrainerPhrase.RegexCheck.Valid -> {
                badges.addView(badge(context.getString(R.string.trainer_regex_valid), Badge.VALID))
                if (story != null) {
                    if (TrainerPhrase.regexMatches(pattern, storyText()) == true) {
                        badges.addView(badge(context.getString(R.string.trainer_regex_matches_story), Badge.VALID))
                    } else {
                        badges.addView(badge(context.getString(R.string.trainer_regex_no_match), Badge.NO_MATCH))
                    }
                }
            }
            is TrainerPhrase.RegexCheck.Invalid -> {
                val message = check.message.ifEmpty { context.getString(R.string.trainer_regex_invalid_pattern) }
                badges.addView(badge(context.getString(R.string.trainer_regex_invalid, message), Badge.ERROR))
            }
            TrainerPhrase.RegexCheck.Empty -> Unit
        }
    }

    /** TrainerRegexInput.swift storyMatchResult: the part of the story this section classifies. */
    private fun storyText(): String? =
        when (kind) {
            TrainerPhraseKind.TITLE -> story?.title
            TrainerPhraseKind.AUTHOR -> story?.authors
            TrainerPhraseKind.TEXT -> story?.content
            TrainerPhraseKind.URL -> story?.permalink
        }

    private enum class Badge { VALID, NO_MATCH, ERROR }

    private fun badge(
        text: String,
        style: Badge,
    ): TextView {
        val (fill, textColor, border) =
            when (style) {
                Badge.VALID -> Triple(colors.validBackground, colors.validText, colors.validBorder)
                Badge.NO_MATCH -> Triple(colors.noMatchBackground, colors.noMatchText, colors.noMatchBorder)
                Badge.ERROR -> Triple(colors.errorBackground, colors.errorText, colors.errorBorder)
            }
        return TextView(context).apply {
            this.text = text
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(textColor)
            setPadding(dp(9), dp(2), dp(9), dp(3))
            background = rounded(fill, dp(10).toFloat(), border)
        }
    }

    private fun styleSegment(
        segment: TextView,
        selected: Boolean,
        selectedFill: Int,
        selectedText: Int,
    ) {
        segment.background = if (selected) rounded(selectedFill, dp(4).toFloat()) else null
        segment.setTextColor(if (selected) selectedText else colors.segmentText)
        segment.isSelected = selected
    }

    private fun placeholder(): String =
        if (isRegex) {
            context.getString(
                R.string.trainer_regex_example,
                when (kind) {
                    TrainerPhraseKind.TITLE -> "\\bbreaking\\b"
                    TrainerPhraseKind.TEXT -> "sponsored|advertisement"
                    TrainerPhraseKind.URL -> "/blog/\\d{4}/"
                    TrainerPhraseKind.AUTHOR -> "^Sam|smith"
                },
            )
        } else {
            context.getString(
                when (kind) {
                    TrainerPhraseKind.TITLE -> R.string.trainer_title_phrase_hint
                    TrainerPhraseKind.TEXT -> R.string.trainer_text_phrase_hint
                    TrainerPhraseKind.URL -> R.string.trainer_url_phrase_hint
                    TrainerPhraseKind.AUTHOR -> R.string.trainer_author_phrase_hint
                },
            )
        }

    private fun label(): Int =
        when (kind) {
            TrainerPhraseKind.TITLE -> if (isRegex) R.string.trainer_label_title_regex else R.string.trainer_label_title
            TrainerPhraseKind.AUTHOR -> if (isRegex) R.string.trainer_label_author_regex else R.string.trainer_label_author
            TrainerPhraseKind.TEXT -> if (isRegex) R.string.trainer_label_text_regex else R.string.trainer_label_text
            TrainerPhraseKind.URL -> if (isRegex) R.string.trainer_label_url_regex else R.string.trainer_label_url
        }

    /** TrainerRegexInput.swift regexHelpContent: four cards of example patterns. */
    private fun showHelp() {
        val content = LinearLayout(context)
        content.orientation = LinearLayout.VERTICAL
        content.setPadding(dp(20), dp(20), dp(20), dp(12))
        content.setBackgroundColor(colors.sheetBackground)
        content.addView(
            TextView(context).apply {
                setText(R.string.trainer_regex_help_title)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
                setTypeface(Typeface.DEFAULT, Typeface.BOLD)
                setTextColor(colors.regexAccent)
                setPadding(0, 0, 0, dp(14))
            },
        )
        val grid = GridLayout(context)
        grid.columnCount = 2
        val cards =
            listOf(
                R.string.trainer_regex_help_word_matching to
                    listOf(
                        "\\bcat\\b" to R.string.trainer_regex_help_whole_word,
                        "cat|dog" to R.string.trainer_regex_help_either_word,
                        "\\bthe cat\\b" to R.string.trainer_exact_phrase,
                    ),
                R.string.trainer_regex_help_position to
                    listOf(
                        "^Breaking" to R.string.trainer_regex_help_starts_with,
                        "update$" to R.string.trainer_regex_help_ends_with,
                        "breaking.*news" to R.string.trainer_regex_help_words_in_order,
                    ),
                R.string.trainer_regex_help_patterns to
                    listOf(
                        "\\d+" to R.string.trainer_regex_help_numbers,
                        "\\$\\d+" to R.string.trainer_regex_help_dollar_amounts,
                        "#\\w+" to R.string.trainer_regex_help_hashtags,
                    ),
                R.string.trainer_regex_help_advanced to
                    listOf(
                        "^(?!.*sponsor)" to R.string.trainer_regex_help_exclude_word,
                        "\\d{4}" to R.string.trainer_regex_help_four_digits,
                        "[A-Z]{2,}" to R.string.trainer_regex_help_acronyms,
                    ),
            )
        cards.forEachIndexed { index, (title, examples) ->
            val card = LinearLayout(context)
            card.orientation = LinearLayout.VERTICAL
            card.setPadding(dp(12), dp(12), dp(12), dp(12))
            card.background = rounded(colors.cardBackground, dp(10).toFloat(), ColorUtils.setAlphaComponent(colors.regexAccent, 38))
            card.addView(
                TextView(context).apply {
                    text = context.getString(title).uppercase()
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                    setTypeface(Typeface.DEFAULT, Typeface.BOLD)
                    letterSpacing = 0.08f
                    setTextColor(colors.regexAccent)
                },
            )
            examples.forEach { (example, description) ->
                card.addView(
                    TextView(context).apply {
                        text = example
                        typeface = Typeface.MONOSPACE
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                        setTextColor(colors.regexAccent)
                        setPadding(dp(5), dp(2), dp(5), dp(2))
                        background = rounded(ColorUtils.setAlphaComponent(colors.regexAccent, 26), dp(4).toFloat())
                    },
                    LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(6) },
                )
                card.addView(
                    TextView(context).apply {
                        setText(description)
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                        setTextColor(colors.textSecondary)
                        setPadding(dp(2), dp(1), 0, 0)
                    },
                )
            }
            grid.addView(
                card,
                GridLayout.LayoutParams(GridLayout.spec(index / 2), GridLayout.spec(index % 2, 1f)).apply {
                    width = 0
                    setMargins(if (index % 2 == 0) 0 else dp(6), if (index < 2) 0 else dp(12), if (index % 2 == 0) dp(6) else 0, 0)
                },
            )
        }
        content.addView(grid)
        content.addView(
            TextView(context).apply {
                setText(R.string.trainer_regex_help_footer)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                setTextColor(colors.textSecondary)
                gravity = Gravity.CENTER
                setPadding(0, dp(16), 0, 0)
            },
        )
        val scroll = ScrollView(context)
        scroll.addView(content)
        val dialog =
            AlertDialog
                .Builder(context)
                .setView(scroll)
                .setPositiveButton(android.R.string.ok, null)
                .create()
        dialog.setOnShowListener {
            dialog.window?.setBackgroundDrawable(rounded(colors.sheetBackground, dp(16).toFloat()))
            dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.setTextColor(colors.regexAccent)
        }
        dialog.show()
    }

    private fun rounded(
        fill: Int,
        radius: Float,
        stroke: Int? = null,
    ) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = radius
        setColor(fill)
        if (stroke != null) setStroke(dp(1), stroke)
    }

    private fun dp(value: Int): Int = (value * density).roundToInt()
}
