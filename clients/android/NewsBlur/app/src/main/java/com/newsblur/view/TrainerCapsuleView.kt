package com.newsblur.view

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.ColorUtils
import androidx.core.view.ViewCompat
import androidx.core.view.isVisible
import androidx.core.view.updateLayoutParams
import com.newsblur.R
import com.newsblur.design.TrainerPalette
import com.newsblur.domain.ClassifierScope
import com.newsblur.fragment.TrainerScores.Level
import kotlin.math.roundToInt

/**
 * One classifier in the trainer, drawn like clients/ios/Classes/TrainerCapsule.swift: a capsule
 * holding the score icon, the optional scope toggles of ScopeToggleView.swift, the "Author: Name"
 * label and the inline dislike and super dislike buttons. Regexes get TrainerCapsule.swift's
 * regexBody (a type badge, monospace pattern and dashed border), and natural language prompts get
 * TrainerAIPromptSection.swift's TrainerPromptCapsule, which wraps long prompts.
 */
class TrainerCapsuleView(
    context: Context,
) : LinearLayout(context) {
    enum class Style { PHRASE, REGEX, PROMPT }

    data class Model(
        val style: Style,
        val level: Level,
        // "Author", "Title Regex", "Content" and so on, already translated.
        val label: String,
        val value: String,
        val showsDislike: Boolean = false,
        val showsSuperDislike: Boolean = false,
        // A typed prompt that isn't added yet, drawn with a dashed border.
        val isDraft: Boolean = false,
        // TrainerAIPromptSection.swift's italic placeholder before anything is typed.
        val isPlaceholder: Boolean = false,
        // A prompt removed in this trainer, struck through until the trainer saves.
        val isRemoved: Boolean = false,
        // ClassifierScope.FEED, FOLDER or GLOBAL, or null to leave out the scope toggles.
        val scope: String? = null,
        val isFolderAvailable: Boolean = true,
    )

    var onTap: (() -> Unit)? = null
    var onDislike: (() -> Unit)? = null
    var onSuperDislike: (() -> Unit)? = null
    var onScope: ((String) -> Unit)? = null

    private val density = resources.displayMetrics.density
    private val medium: Typeface? = ResourcesCompat.getFont(context, R.font.whitney_ssm_medium_bas)

    private val body = LinearLayout(context)
    private val scoreIcon = ImageView(context)

    /** The publisher's favicon, between "Site:" and its name, which IntelTrainerSections.kt loads. */
    val favicon = ImageView(context)
    private val scopeGroup = LinearLayout(context)
    private val scopeButtons =
        listOf(ClassifierScope.FEED, ClassifierScope.FOLDER, ClassifierScope.GLOBAL).associateWith { ImageView(context) }
    private val badge = TextView(context)

    // TrainerCapsule.swift content: the dimmer "Site:" before the publisher's favicon. Other
    // capsules put their "Author:" inline in the label.
    private val prefix = TextView(context)
    private val label = TextView(context)
    private val divider = View(context)
    private val dislikeButton = ImageView(context)
    private val superDislikeButton = ImageView(context)

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        body.orientation = HORIZONTAL
        body.gravity = Gravity.CENTER_VERTICAL
        addView(body, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { weight = 1f })
        body.addView(scoreIcon, LayoutParams(dp(16), dp(16)))
        scoreIcon.importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO

        scopeGroup.orientation = HORIZONTAL
        scopeGroup.gravity = Gravity.CENTER_VERTICAL
        body.addView(scopeGroup, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { marginStart = dp(3) })
        scopeButtons.forEach { (scope, button) ->
            button.setImageResource(
                when (scope) {
                    ClassifierScope.FOLDER -> R.drawable.ic_trainer_scope_folder
                    ClassifierScope.GLOBAL -> R.drawable.ic_trainer_scope_global
                    else -> R.drawable.ic_trainer_scope_feed
                },
            )
            button.contentDescription =
                context.getString(
                    when (scope) {
                        ClassifierScope.FOLDER -> R.string.ai_scope_folder
                        ClassifierScope.GLOBAL -> R.string.ai_scope_global
                        else -> R.string.ai_scope_feed
                    },
                )
            // ScopeToggleView.swift: 12pt icons in 18pt frames, a touch larger here for fingers.
            button.setPadding(dp(4), dp(4), dp(4), dp(4))
            button.background = ripple(oval = true)
            button.setOnClickListener { onScope?.invoke(scope) }
            scopeGroup.addView(button, LayoutParams(dp(20), dp(20)))
        }

        badge.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
        badge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 9f)
        badge.letterSpacing = 0.04f
        badge.setPadding(dp(5), dp(1), dp(5), dp(1))
        badge.isSingleLine = true
        body.addView(badge, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { marginStart = dp(6) })

        prefix.typeface = medium
        prefix.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        prefix.isSingleLine = true
        body.addView(prefix, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply { marginStart = dp(7) })

        favicon.importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        favicon.isVisible = false
        body.addView(favicon, LayoutParams(dp(16), dp(16)).apply { marginStart = dp(5) })

        body.addView(label, LayoutParams(0, LayoutParams.WRAP_CONTENT).apply { weight = 1f })
        body.setOnClickListener { onTap?.invoke() }

        addView(divider, LayoutParams(dp(1), dp(18)))
        listOf(dislikeButton, superDislikeButton).forEach { button ->
            button.scaleType = ImageView.ScaleType.CENTER_INSIDE
            button.setPadding(dp(7), dp(7), dp(7), dp(7))
            addView(button, LayoutParams(dp(28), dp(28)))
        }
        dislikeButton.setImageResource(R.drawable.ic_thumb_down_red)
        dislikeButton.setOnClickListener { onDislike?.invoke() }
        superDislikeButton.setImageResource(R.drawable.ic_thumb_down_double_crimson)
        superDislikeButton.contentDescription = context.getString(R.string.intel_super_dislike)
        superDislikeButton.setOnClickListener { onSuperDislike?.invoke() }
    }

    fun bind(
        model: Model,
        colors: TrainerPalette.Colors,
    ) {
        val isActive = model.level != Level.NEUTRAL
        val isPrompt = model.style == Style.PROMPT
        val isRegex = model.style == Style.REGEX
        val hasButtons = model.showsDislike || model.showsSuperDislike

        // Score icon: TrainerCapsule.swift scoreIcon, regexIconColor and TrainerPromptCapsule's icon.
        scoreIcon.setImageResource(
            when (model.level) {
                Level.LIKE -> R.drawable.ic_thumb_up_green
                Level.DISLIKE -> R.drawable.ic_thumb_down_red
                Level.SUPER_DISLIKE -> R.drawable.ic_thumb_down_double_crimson
                Level.NEUTRAL -> R.drawable.ic_trainer_thumb_up_outline
            },
        )
        scoreIcon.imageTintList =
            ColorStateList.valueOf(
                when {
                    isActive -> colors.capsuleActiveText
                    isRegex -> colors.regexNeutralIcon
                    isPrompt -> colors.capsuleNeutralLabel
                    else -> colors.capsuleNeutralIcon
                },
            )
        val iconSize = if (model.level == Level.SUPER_DISLIKE) dp(18) else dp(15)
        scoreIcon.updateLayoutParams<LayoutParams> {
            width = iconSize
            height = iconSize
        }

        bindScope(model, colors)

        // The type badge: regexes and prompts only. TrainerCapsule.swift regexBadgeBackground.
        badge.isVisible = isRegex || isPrompt
        badge.text = model.label.uppercase()
        badge.setTextColor(colors.capsuleActiveText)
        badge.background =
            rounded(
                when {
                    isActive -> ColorUtils.setAlphaComponent(colors.capsuleActiveText, 64)
                    isPrompt -> colors.promptAccent
                    else -> colors.regexAccent
                },
                radius = dp(3).toFloat(),
            )

        bindLabel(model, colors, isActive)

        // TrainerCapsule.swift trailingButtons.
        divider.isVisible = hasButtons
        divider.setBackgroundColor(if (isActive) ColorUtils.setAlphaComponent(colors.capsuleActiveText, 64) else colors.capsuleDivider)
        // A prompt's thumbs down hides its matches rather than disliking them.
        dislikeButton.contentDescription = context.getString(if (isPrompt) R.string.ai_prompt_hide else R.string.explainer_dislike)
        bindInlineButton(
            dislikeButton,
            model.showsDislike,
            model.level == Level.DISLIKE,
            isActive,
            colors.dislikeIcon,
            colors.capsuleDislike,
            colors,
        )
        bindInlineButton(
            superDislikeButton,
            model.showsSuperDislike,
            model.level == Level.SUPER_DISLIKE,
            isActive,
            colors.superDislikeIcon,
            colors.capsuleSuperDislike,
            colors,
        )

        val verticalPadding = if (isPrompt || isRegex) dp(6) else dp(5)
        body.setPadding(dp(9), verticalPadding, if (hasButtons) dp(6) else dp(if (isRegex || isPrompt) 12 else 10), verticalPadding)
        setPadding(0, 0, if (hasButtons) dp(4) else 0, 0)
        minimumHeight = dp(32)

        val radius = if (isPrompt) dp(15).toFloat() else dp(100).toFloat()
        val fill =
            when (model.level) {
                Level.LIKE -> colors.capsuleLike
                Level.DISLIKE -> colors.capsuleDislike
                Level.SUPER_DISLIKE -> colors.capsuleSuperDislike
                Level.NEUTRAL -> if (isRegex) colors.regexNeutral else colors.capsuleNeutral
            }
        val background = rounded(fill, radius)
        when {
            // TrainerCapsule.swift dashedBorderColor: every regex has a dashed border.
            isRegex -> background.setStroke(dp(1.5f), regexBorder(model.level, colors), dp(4f).toFloat(), dp(3f).toFloat())
            model.isDraft || model.isPlaceholder ->
                background.setStroke(
                    dp(1.5f),
                    ColorUtils.setAlphaComponent(if (isActive) colors.capsuleActiveText else colors.promptAccent, 153),
                    dp(4f).toFloat(),
                    dp(3f).toFloat(),
                )
        }
        this.background = background
        body.background = ripple(oval = false, radius = radius)
        body.isClickable = onTap != null
        ViewCompat.setStateDescription(body, stateDescription(model.level))
    }

    private fun bindScope(
        model: Model,
        colors: TrainerPalette.Colors,
    ) {
        val scope = model.scope
        scopeGroup.isVisible = scope != null
        if (scope == null) return
        // ScopeToggleView.swift iconColor: white on a liked or disliked capsule, colored on a neutral one.
        val isScored = model.level != Level.NEUTRAL
        scopeButtons.forEach { (buttonScope, button) ->
            val isActive = buttonScope == scope
            val color =
                when {
                    isScored -> colors.capsuleActiveText
                    !isActive -> colors.scopeInactive
                    buttonScope == ClassifierScope.FOLDER -> colors.scopeFolderActive
                    buttonScope == ClassifierScope.GLOBAL -> colors.scopeGlobalActive
                    else -> colors.scopeFeedActive
                }
            button.imageTintList = ColorStateList.valueOf(color)
            // ScopeToggleView.swift dims the folder further when there's no folder to scope to.
            button.alpha =
                when {
                    isActive -> 1f
                    buttonScope == ClassifierScope.FOLDER && !model.isFolderAvailable -> 0.2f
                    else -> 0.5f
                }
            button.isSelected = isActive
        }
    }

    private fun bindLabel(
        model: Model,
        colors: TrainerPalette.Colors,
        isActive: Boolean,
    ) {
        val valueColor =
            when {
                isActive -> colors.capsuleActiveText
                model.isPlaceholder -> colors.textSecondary
                model.style == Style.REGEX -> colors.regexText
                model.style == Style.PROMPT -> colors.textPrimary
                else -> colors.capsuleNeutralText
            }
        label.setTextColor(valueColor)
        val labelColor = if (isActive) colors.capsuleActiveLabel else colors.capsuleNeutralLabel
        val header =
            if (model.style == Style.PHRASE &&
                model.label.isNotEmpty()
            ) {
                context.getString(R.string.trainer_capsule_label, model.label)
            } else {
                null
            }
        // The header runs inline so a long value wraps under it, except around the publisher's favicon.
        prefix.isVisible = header != null && favicon.isVisible
        prefix.text = header
        prefix.setTextColor(labelColor)
        // updateLayoutParams resolves the start margin again, which a capsule rebinding needs.
        label.updateLayoutParams<LayoutParams> { marginStart = dp(if (favicon.isVisible) 5 else 7) }
        label.text =
            if (header != null && !favicon.isVisible) {
                SpannableStringBuilder(header).apply {
                    setSpan(ForegroundColorSpan(labelColor), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    append(" ").append(model.value)
                }
            } else {
                model.value
            }
        when (model.style) {
            Style.PHRASE -> {
                label.typeface = medium
                label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            }
            Style.REGEX -> {
                label.typeface = Typeface.MONOSPACE
                label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            }
            Style.PROMPT -> {
                label.typeface = if (model.isPlaceholder) Typeface.create(medium, Typeface.ITALIC) else medium
                label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            }
        }
        label.paintFlags =
            if (model.isRemoved) label.paintFlags or Paint.STRIKE_THRU_TEXT_FLAG else label.paintFlags and Paint.STRIKE_THRU_TEXT_FLAG.inv()
    }

    private fun bindInlineButton(
        button: ImageView,
        isShown: Boolean,
        isOn: Boolean,
        capsuleActive: Boolean,
        idleColor: Int,
        onColor: Int,
        colors: TrainerPalette.Colors,
    ) {
        button.isVisible = isShown
        if (!isShown) return
        // TrainerCapsule.swift dislikeIconColor: white when on, half white on another opinion.
        button.imageTintList =
            ColorStateList.valueOf(
                when {
                    isOn -> colors.capsuleActiveText
                    capsuleActive -> ColorUtils.setAlphaComponent(colors.capsuleActiveText, 128)
                    else -> idleColor
                },
            )
        val circle =
            GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(if (isOn) onColor else 0)
            }
        button.background =
            RippleDrawable(
                ColorStateList.valueOf(RIPPLE),
                circle,
                GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(-1)
                },
            )
        button.isSelected = isOn
    }

    private fun regexBorder(
        level: Level,
        colors: TrainerPalette.Colors,
    ): Int =
        when (level) {
            Level.LIKE -> 0xFF005900.toInt()
            Level.SUPER_DISLIKE -> 0xFF6B0000.toInt()
            Level.DISLIKE -> 0xFFB30000.toInt()
            Level.NEUTRAL -> colors.regexNeutralIcon
        }

    private fun stateDescription(level: Level): String? =
        when (level) {
            Level.LIKE -> context.getString(R.string.explainer_like)
            Level.DISLIKE -> context.getString(R.string.explainer_dislike)
            Level.SUPER_DISLIKE -> context.getString(R.string.intel_super_dislike)
            Level.NEUTRAL -> null
        }

    private fun rounded(
        color: Int,
        radius: Float,
    ) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = radius
        setColor(color)
    }

    private fun ripple(
        oval: Boolean,
        radius: Float = 0f,
    ): Drawable {
        val mask =
            GradientDrawable().apply {
                if (oval) shape = GradientDrawable.OVAL else cornerRadius = radius
                setColor(-1)
            }
        return RippleDrawable(ColorStateList.valueOf(RIPPLE), null, mask)
    }

    private fun dp(value: Int): Int = (value * density).roundToInt()

    private fun dp(value: Float): Int = (value * density).roundToInt()

    private companion object {
        const val RIPPLE = 0x33000000
    }
}
