package com.newsblur.activity

import android.content.Context
import android.content.res.Configuration
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ReplacementSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import kotlin.math.ceil
import androidx.appcompat.content.res.AppCompatResources
import androidx.core.graphics.drawable.DrawableCompat
import com.newsblur.R
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils

class ReadingTraverseBar(
    private val context: Context,
    private val binding: ActivityReadingBinding,
    selectedTheme: ThemeValue,
) {
    private val iconSizeDp = 14
    private val sendIconSizeDp = 12
    private val previousChevronSizeDp = 12
    private val nextChevronSizeDp = 24
    private val textButtonStartPaddingDp = 12
    private val textButtonEndPaddingDp = 12
    private val textButtonDrawablePaddingDp = 6
    private val textButtonMarginStartDp = 8
    private val nextButtonStartPaddingDp = 6
    private val nextButtonEndPaddingDp = 10

    private var resolvedTheme = resolveTheme(selectedTheme)
    var palette = paletteFor(resolvedTheme)
        private set

    private var previousEnabled = false
    private var nextShowsDone = false
    private var textModeEnabled = true
    private var inTextView = false
    private var sendEnabled = true

    fun setup() {
        configureTextButton()
        configureNextButton()
        configureImageButtons()
        applyPalette()
        syncState()
    }

    fun updateTheme(selectedTheme: ThemeValue) {
        resolvedTheme = resolveTheme(selectedTheme)
        palette = paletteFor(resolvedTheme)
        applyPalette()
        syncState()
    }

    fun updatePreviousEnabled(enabled: Boolean) {
        previousEnabled = enabled
        binding.readingOverlayLeft.isEnabled = enabled
        binding.readingOverlayLeft.alpha = if (enabled) 1f else 0.35f
    }

    fun updateNextShowDone(showDone: Boolean) {
        nextShowsDone = showDone
        binding.readingOverlayRight.text = context.getString(if (showDone) R.string.overlay_done else R.string.overlay_next)
        binding.readingOverlayRight.contentDescription = binding.readingOverlayRight.text
        binding.readingOverlayRight.setCompoundDrawablesRelative(
            null,
            null,
            sizedTintedDrawable(
                if (showDone) R.drawable.ic_checkmark else R.drawable.ic_chevron_right,
                palette.tintColor,
                if (showDone) previousChevronSizeDp else nextChevronSizeDp,
            ),
            null,
        )
    }

    fun updateTextInTextView(
        inTextView: Boolean,
        enabled: Boolean,
    ) {
        this.inTextView = inTextView
        textModeEnabled = enabled

        val label = context.getString(if (inTextView) R.string.overlay_story else R.string.overlay_text)
        binding.readingOverlayText.text = reservedTextButtonLabel(label)
        binding.readingOverlayText.contentDescription = label
        binding.readingOverlayText.setCompoundDrawablesRelative(
            sizedTintedDrawable(
                if (inTextView) R.drawable.ic_story_feed_gray46 else R.drawable.ic_story_text_gray46,
                palette.tintColor,
                14,
            ),
            null,
            null,
            null,
        )
        binding.readingOverlayText.background =
            if (inTextView) {
                activeTextButtonBackground()
            } else {
                buttonBackground(cornerRadiusDp = 8f, color = Color.TRANSPARENT)
            }
        // Re-apply padding after setting background; InsetDrawable overrides
        // the view's padding with its own insets, losing our start padding.
        binding.readingOverlayText.setPaddingRelative(
            UIUtils.dp2px(context, textButtonStartPaddingDp),
            0,
            UIUtils.dp2px(context, textButtonEndPaddingDp),
            0,
        )
        binding.readingOverlayText.isEnabled = enabled
        binding.readingOverlayText.alpha = if (enabled) 1f else 0.4f
        binding.readingOverlayText.setTextColor(palette.tintColor)
    }

    fun updateSendEnabled(enabled: Boolean) {
        sendEnabled = enabled
        binding.readingOverlaySend.isEnabled = enabled
        binding.readingOverlaySend.alpha = if (enabled) 1f else 0.4f
    }

    private fun syncState() {
        updatePreviousEnabled(previousEnabled)
        updateNextShowDone(nextShowsDone)
        updateTextInTextView(inTextView, textModeEnabled)
        updateSendEnabled(sendEnabled)
    }

    private fun applyPalette() {
        binding.readingOverlayLeftGroup.background = groupBackground()
        binding.readingOverlayRightGroup.background = groupBackground()

        binding.readingOverlayLeftSeparator.setBackgroundColor(palette.separatorColor)
        binding.readingOverlayRightSeparator.setBackgroundColor(palette.separatorColor)

        binding.readingOverlayProgress.setIndicatorColor(palette.progressColor)
        binding.readingOverlayProgress.trackColor = palette.progressTrackColor
        binding.readingOverlayProgressRight.setIndicatorColor(palette.tintColor)
        binding.readingOverlayProgressLeft.setIndicatorColor(palette.tintColor)

        binding.readingOverlaySend.background = buttonBackground(cornerRadiusDp = 12f, color = Color.TRANSPARENT)
        binding.readingOverlayLeft.background = buttonBackground(cornerRadiusDp = 12f, color = Color.TRANSPARENT)
        binding.readingOverlayRight.background = buttonBackground(cornerRadiusDp = 12f, color = Color.TRANSPARENT)

        binding.readingOverlaySend.setImageDrawable(sizedTintedDrawable(R.drawable.ic_send_to, palette.tintColor, sendIconSizeDp))
        binding.readingOverlayLeft.setImageDrawable(
            sizedTintedDrawable(
                R.drawable.ic_chevron_left,
                palette.tintColor,
                previousChevronSizeDp,
            ),
        )
    }

    private fun configureTextButton() {
        binding.readingOverlayText.apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            gravity = Gravity.CENTER
            compoundDrawablePadding = UIUtils.dp2px(context, textButtonDrawablePaddingDp)
            setPaddingRelative(
                UIUtils.dp2px(context, textButtonStartPaddingDp),
                0,
                UIUtils.dp2px(context, textButtonEndPaddingDp),
                0,
            )
            minimumWidth = 0
            minimumHeight = 0
            includeFontPadding = false
        }
        binding.readingOverlayText.layoutParams =
            binding.readingOverlayText.layoutParams.apply {
                width = stableTextButtonWidth()
                if (this is ViewGroup.MarginLayoutParams) {
                    marginStart = UIUtils.dp2px(context, textButtonMarginStartDp)
                }
            }
    }

    private fun configureNextButton() {
        binding.readingOverlayRight.apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            gravity = Gravity.CENTER
            compoundDrawablePadding = UIUtils.dp2px(context, 4)
            setPaddingRelative(
                UIUtils.dp2px(context, nextButtonStartPaddingDp),
                0,
                UIUtils.dp2px(context, nextButtonEndPaddingDp),
                0,
            )
            minimumWidth = 0
            minimumHeight = 0
            includeFontPadding = false
        }
    }

    private fun configureImageButtons() {
        val iconPadding = UIUtils.dp2px(context, 10)
        val sendPadding = UIUtils.dp2px(context, 12)
        binding.readingOverlaySend.setPadding(sendPadding, sendPadding, sendPadding, sendPadding)
        binding.readingOverlayLeft.setPadding(iconPadding, iconPadding, iconPadding, iconPadding)
    }

    private fun groupBackground(): Drawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = UIUtils.dp2px(context, 12f)
            setColor(palette.groupBackgroundColor)
        }

    private fun buttonBackground(
        cornerRadiusDp: Float,
        color: Int,
    ): Drawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = UIUtils.dp2px(context, cornerRadiusDp)
            setColor(color)
        }

    private fun activeTextButtonBackground(): Drawable {
        val separatorGap = UIUtils.dp2px(context, 4)
        return InsetDrawable(
            buttonBackground(
                cornerRadiusDp = 8f,
                color = palette.activeTextBackgroundColor,
            ),
            0,
            0,
            separatorGap,
            0,
        )
    }

    private fun tintedDrawable(
        drawableRes: Int,
        tintColor: Int,
    ): Drawable? {
        val drawable = AppCompatResources.getDrawable(context, drawableRes) ?: return null
        val wrapped = DrawableCompat.wrap(drawable.mutate())
        DrawableCompat.setTint(wrapped, tintColor)
        return wrapped
    }

    private fun sizedTintedDrawable(
        drawableRes: Int,
        tintColor: Int,
        sizeDp: Int,
    ): Drawable? {
        val drawable = tintedDrawable(drawableRes, tintColor) ?: return null
        val sizePx = UIUtils.dp2px(context, sizeDp)
        drawable.setBounds(0, 0, sizePx, sizePx)
        return drawable
    }

    private fun stableTextButtonWidth(): Int {
        val labelWidth = maxTextButtonLabelWidth()
        val horizontalPadding = binding.readingOverlayText.paddingStart + binding.readingOverlayText.paddingEnd
        val iconWidth = UIUtils.dp2px(context, iconSizeDp)
        val drawablePadding = binding.readingOverlayText.compoundDrawablePadding
        return labelWidth + horizontalPadding + iconWidth + drawablePadding
    }

    private fun reservedTextButtonLabel(label: String): CharSequence {
        val reserveWidth = maxTextButtonLabelWidth() - measureTextButtonLabelWidth(label)
        if (reserveWidth <= 0) return label

        return SpannableStringBuilder(label).apply {
            append('\u00A0')
            setSpan(
                ReservedWidthSpan(reserveWidth),
                length - 1,
                length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
    }

    private fun maxTextButtonLabelWidth(): Int =
        listOf(
            context.getString(R.string.overlay_text),
            context.getString(R.string.overlay_story),
        ).maxOf(::measureTextButtonLabelWidth)

    private fun measureTextButtonLabelWidth(label: String): Int =
        ceil(binding.readingOverlayText.paint.measureText(label).toDouble()).toInt()

    private fun resolveTheme(selectedTheme: ThemeValue): ThemeValue =
        when (selectedTheme) {
            ThemeValue.AUTO -> {
                when (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) {
                    Configuration.UI_MODE_NIGHT_YES -> ThemeValue.DARK
                    else -> ThemeValue.LIGHT
                }
            }

            else -> selectedTheme
        }

    private fun paletteFor(theme: ThemeValue): ReadingTraversePalette =
        when (theme) {
            ThemeValue.SEPIA ->
                ReadingTraversePalette(
                    groupBackgroundColor = 0xFFEADFD0.toInt(),
                    separatorColor = 0xFFD4C8B8.toInt(),
                    tintColor = 0xFF6A5A4A.toInt(),
                    activeTextBackgroundColor = 0xFFDDD0C0.toInt(),
                    progressColor = 0x808B7B6B.toInt(),
                    progressTrackColor = 0x4DC0B0A0,
                )

            ThemeValue.DARK ->
                ReadingTraversePalette(
                    groupBackgroundColor = 0xFF444444.toInt(),
                    separatorColor = 0xFF555555.toInt(),
                    tintColor = 0xFFAAAAAA.toInt(),
                    activeTextBackgroundColor = 0xFF555555.toInt(),
                    progressColor = 0x80888888.toInt(),
                    progressTrackColor = 0x4D555555,
                )

            ThemeValue.BLACK ->
                ReadingTraversePalette(
                    groupBackgroundColor = 0xFF2A2A2A.toInt(),
                    separatorColor = 0xFF3A3A3A.toInt(),
                    tintColor = 0xFFAAAAAA.toInt(),
                    activeTextBackgroundColor = 0xFF404040.toInt(),
                    progressColor = 0x80888888.toInt(),
                    progressTrackColor = 0x4D444444,
                )

            else ->
                ReadingTraversePalette(
                    groupBackgroundColor = 0xFFE3E6E0.toInt(),
                    separatorColor = 0xFFCED0CC.toInt(),
                    tintColor = 0xFF555555.toInt(),
                    activeTextBackgroundColor = 0xFFD0D5CC.toInt(),
                    progressColor = 0x80808080.toInt(),
                    progressTrackColor = 0x4DC0C0C0,
                )
        }
}

data class ReadingTraversePalette(
    val groupBackgroundColor: Int,
    val separatorColor: Int,
    val tintColor: Int,
    val activeTextBackgroundColor: Int,
    val progressColor: Int,
    val progressTrackColor: Int,
)

private class ReservedWidthSpan(
    private val widthPx: Int,
) : ReplacementSpan() {
    override fun getSize(
        paint: Paint,
        text: CharSequence,
        start: Int,
        end: Int,
        fm: Paint.FontMetricsInt?,
    ): Int = widthPx

    override fun draw(
        canvas: Canvas,
        text: CharSequence,
        start: Int,
        end: Int,
        x: Float,
        top: Int,
        y: Int,
        bottom: Int,
        paint: Paint,
    ) {
    }
}
