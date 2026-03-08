package com.newsblur.activity

import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.View
import androidx.appcompat.content.res.AppCompatResources
import androidx.core.graphics.drawable.DrawableCompat
import com.google.android.material.button.MaterialButton
import com.newsblur.R
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils

class ReadingTraverseBar(
    private val context: Context,
    private val binding: ActivityReadingBinding,
    selectedTheme: ThemeValue,
) {
    private var resolvedTheme = resolveTheme(selectedTheme)
    private var palette = paletteFor(resolvedTheme)

    private var previousEnabled = false
    private var nextShowsDone = false
    private var textModeEnabled = true
    private var inTextView = false
    private var sendEnabled = true

    fun setup() {
        configureTextButton()
        configureIconButton(binding.readingOverlaySend)
        configureIconButton(binding.readingOverlayLeft)
        configureNextButton()
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
        binding.readingOverlayRight.icon =
            tintedDrawable(
                if (showDone) R.drawable.ic_checkmark else R.drawable.ic_chevron_right,
                palette.tintColor,
            )
    }

    fun updateTextInTextView(
        inTextView: Boolean,
        enabled: Boolean,
    ) {
        this.inTextView = inTextView
        textModeEnabled = enabled

        binding.readingOverlayText.text = context.getString(if (inTextView) R.string.overlay_story else R.string.overlay_text)
        binding.readingOverlayText.contentDescription = binding.readingOverlayText.text
        binding.readingOverlayText.icon =
            tintedDrawable(
                if (inTextView) R.drawable.ic_story_feed_gray46 else R.drawable.ic_story_text_gray46,
                palette.tintColor,
            )
        binding.readingOverlayText.backgroundTintList =
            ColorStateList.valueOf(if (inTextView) palette.activeTextBackgroundColor else Color.TRANSPARENT)
        binding.readingOverlayText.isEnabled = enabled
        binding.readingOverlayText.alpha = if (enabled) 1f else 0.4f
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

        applyButtonChrome(binding.readingOverlaySend, cornerRadiusDp = 12f, backgroundColor = Color.TRANSPARENT)
        applyButtonChrome(binding.readingOverlayLeft, cornerRadiusDp = 12f, backgroundColor = Color.TRANSPARENT)
        applyButtonChrome(binding.readingOverlayRight, cornerRadiusDp = 12f, backgroundColor = Color.TRANSPARENT)
        applyButtonChrome(
            binding.readingOverlayText,
            cornerRadiusDp = 8f,
            backgroundColor = if (inTextView) palette.activeTextBackgroundColor else Color.TRANSPARENT,
        )

        binding.readingOverlaySend.icon = tintedDrawable(R.drawable.ic_send_to, palette.tintColor)
        binding.readingOverlayLeft.icon = tintedDrawable(R.drawable.ic_chevron_left, palette.tintColor)
    }

    private fun configureTextButton() {
        binding.readingOverlayText.apply {
            iconGravity = MaterialButton.ICON_GRAVITY_TEXT_START
            iconPadding = UIUtils.dp2px(context, 6)
            iconSize = UIUtils.dp2px(context, 14)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            setPaddingRelative(UIUtils.dp2px(context, 14), 0, UIUtils.dp2px(context, 14), 0)
            minimumWidth = 0
            minimumHeight = 0
        }
    }

    private fun configureIconButton(button: MaterialButton) {
        button.apply {
            iconGravity = MaterialButton.ICON_GRAVITY_TEXT_START
            iconSize = UIUtils.dp2px(context, 15)
            minimumWidth = 0
            minimumHeight = 0
            setPadding(0, 0, 0, 0)
        }
    }

    private fun configureNextButton() {
        binding.readingOverlayRight.apply {
            iconGravity = MaterialButton.ICON_GRAVITY_TEXT_END
            iconPadding = UIUtils.dp2px(context, 4)
            iconSize = UIUtils.dp2px(context, 12)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            setPaddingRelative(UIUtils.dp2px(context, 6), 0, UIUtils.dp2px(context, 14), 0)
            minimumWidth = 0
            minimumHeight = 0
        }
    }

    private fun applyButtonChrome(
        button: MaterialButton,
        cornerRadiusDp: Float,
        backgroundColor: Int,
    ) {
        button.apply {
            strokeWidth = 0
            insetTop = 0
            insetBottom = 0
            iconTint = null
            backgroundTintList = ColorStateList.valueOf(backgroundColor)
            rippleColor = ColorStateList.valueOf(palette.pressHighlightColor)
            cornerRadius = UIUtils.dp2px(context, cornerRadiusDp).toInt()
            setTextColor(palette.tintColor)
        }
    }

    private fun groupBackground(): Drawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = UIUtils.dp2px(context, 12f)
            setColor(palette.groupBackgroundColor)
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
                    pressHighlightColor = 0xFFDDD0C0.toInt(),
                    progressColor = 0x808B7B6B.toInt(),
                    progressTrackColor = 0x4DC0B0A0,
                )

            ThemeValue.DARK ->
                ReadingTraversePalette(
                    groupBackgroundColor = 0xFF444444.toInt(),
                    separatorColor = 0xFF555555.toInt(),
                    tintColor = 0xFFAAAAAA.toInt(),
                    activeTextBackgroundColor = 0xFF555555.toInt(),
                    pressHighlightColor = 0xFF555555.toInt(),
                    progressColor = 0x80888888.toInt(),
                    progressTrackColor = 0x4D555555,
                )

            ThemeValue.BLACK ->
                ReadingTraversePalette(
                    groupBackgroundColor = 0xFF2A2A2A.toInt(),
                    separatorColor = 0xFF3A3A3A.toInt(),
                    tintColor = 0xFFAAAAAA.toInt(),
                    activeTextBackgroundColor = 0xFF404040.toInt(),
                    pressHighlightColor = 0xFF3A3A3A.toInt(),
                    progressColor = 0x80888888.toInt(),
                    progressTrackColor = 0x4D444444,
                )

            else ->
                ReadingTraversePalette(
                    groupBackgroundColor = 0xFFE3E6E0.toInt(),
                    separatorColor = 0xFFCED0CC.toInt(),
                    tintColor = 0xFF555555.toInt(),
                    activeTextBackgroundColor = 0xFFD0D5CC.toInt(),
                    pressHighlightColor = 0xFFCDD2C8.toInt(),
                    progressColor = 0x80808080.toInt(),
                    progressTrackColor = 0x4DC0C0C0,
                )
        }
}

private data class ReadingTraversePalette(
    val groupBackgroundColor: Int,
    val separatorColor: Int,
    val tintColor: Int,
    val activeTextBackgroundColor: Int,
    val pressHighlightColor: Int,
    val progressColor: Int,
    val progressTrackColor: Int,
)
