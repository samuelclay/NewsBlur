package com.newsblur.view

import android.animation.ArgbEvaluator
import android.animation.ValueAnimator
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.AttributeSet
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.newsblur.R
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants
import com.newsblur.util.UIUtils

class BottomNextFeedControl
    @JvmOverloads
    constructor(
        context: Context,
        attrs: AttributeSet? = null,
    ) : FrameLayout(context, attrs) {
        private val cardView = LinearLayout(context)
        private val arrowContainer = FrameLayout(context)
        private val arrowImageView = ImageView(context)
        private val targetIconView = ImageView(context)
        private val titleView = TextView(context)
        private val cardBackground = GradientDrawable()
        private val arrowBackground = GradientDrawable()
        private val argbEvaluator = ArgbEvaluator()

        private var palette = paletteFor(PrefConstants.ThemeValue.LIGHT)
        private var currentArrowBackgroundColor = palette.inactiveArrowBackgroundColor
        private var currentArrowTintColor = palette.inactiveArrowColor
        private var currentTitleColor = palette.inactiveTitleColor
        private var ready = false
        private var didConfigureReadyState = false
        private var targetIconUsesTemplate = true

        init {
            isClickable = true
            isFocusable = true
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
            alpha = 0f
            visibility = GONE

            cardBackground.cornerRadius = dp(12).toFloat()
            cardView.background = cardBackground
            cardView.clipToOutline = true
            cardView.gravity = Gravity.CENTER_VERTICAL
            cardView.orientation = LinearLayout.HORIZONTAL
            cardView.setPadding(dp(12), 0, dp(14), 0)
            addView(
                cardView,
                LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT).apply {
                    topMargin = dp(4)
                    bottomMargin = dp(4)
                },
            )

            arrowBackground.cornerRadius = dp(13).toFloat()
            arrowContainer.background = arrowBackground
            cardView.addView(
                arrowContainer,
                LinearLayout.LayoutParams(dp(26), dp(26)),
            )

            arrowImageView.setImageResource(R.drawable.ic_arrow_up)
            arrowImageView.scaleType = ImageView.ScaleType.CENTER_INSIDE
            arrowContainer.addView(
                arrowImageView,
                LayoutParams(dp(17), dp(17), Gravity.CENTER),
            )

            targetIconView.scaleType = ImageView.ScaleType.FIT_CENTER
            cardView.addView(
                targetIconView,
                LinearLayout.LayoutParams(dp(22), dp(22)).apply {
                    marginStart = dp(10)
                },
            )

            titleView.ellipsize = TextUtils.TruncateAt.END
            titleView.includeFontPadding = false
            titleView.maxLines = 1
            titleView.setTypeface(Typeface.DEFAULT, Typeface.BOLD)
            titleView.textSize = 16.5f
            cardView.addView(
                titleView,
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginStart = dp(9)
                },
            )

            applyTheme(PrefConstants.ThemeValue.LIGHT)
            configure("site", null, false)
        }

        fun configure(
            kind: String?,
            title: String?,
            ready: Boolean,
        ) {
            val isFolder = kind == "folder"
            val cleanTitle = title?.takeIf { it.isNotBlank() } ?: context.getString(R.string.feed_list)
            titleView.text = cleanTitle
            contentDescription =
                if (isFolder) {
                    context.getString(R.string.bottom_next_unread_folder, cleanTitle)
                } else {
                    context.getString(R.string.bottom_next_unread_site, cleanTitle)
                }
            setReady(ready)
        }

        fun applyTheme(theme: PrefConstants.ThemeValue) {
            palette = paletteFor(theme)
            cardBackground.setColor(palette.cardColor)
            cardBackground.setStroke(dp(1), palette.borderColor)
            setArrowBackgroundColor(if (ready) palette.activeArrowBackgroundColor else palette.inactiveArrowBackgroundColor)
            setArrowTintColor(if (ready) Color.WHITE else palette.inactiveArrowColor)
            setTitleColor(if (ready) palette.activeTitleColor else palette.inactiveTitleColor)
            applyTargetIconTint()
        }

        fun setTargetIconBitmap(bitmap: Bitmap?) {
            if (bitmap == null) return
            targetIconUsesTemplate = false
            targetIconView.imageTintList = null
            targetIconView.setImageBitmap(bitmap)
        }

        fun setTargetIconResource(resourceId: Int) {
            targetIconUsesTemplate = true
            targetIconView.setImageResource(resourceId)
            applyTargetIconTint()
        }

        fun loadTargetIcon(
            imageLoader: ImageLoader,
            url: String?,
            fallbackResourceId: Int,
        ) {
            targetIconUsesTemplate = false
            targetIconView.imageTintList = null
            targetIconView.setImageResource(fallbackResourceId)
            imageLoader.displayImage(url, targetIconView)
        }

        private fun setReady(nextReady: Boolean) {
            val shouldAnimate = didConfigureReadyState && ready != nextReady
            ready = nextReady
            didConfigureReadyState = true
            applyReadyState(nextReady, shouldAnimate)
        }

        private fun applyReadyState(
            nextReady: Boolean,
            animated: Boolean,
        ) {
            val targetArrowBackground = if (nextReady) palette.activeArrowBackgroundColor else palette.inactiveArrowBackgroundColor
            val targetArrowTint = if (nextReady) Color.WHITE else palette.inactiveArrowColor
            val targetTitle = if (nextReady) palette.activeTitleColor else palette.inactiveTitleColor
            val targetRotation = if (nextReady) 180f else 0f
            val targetScale = if (nextReady) 1.06f else 1f
            val targetIconAlpha = if (nextReady) 1f else 0.74f

            if (!animated) {
                setArrowBackgroundColor(targetArrowBackground)
                setArrowTintColor(targetArrowTint)
                setTitleColor(targetTitle)
                arrowImageView.rotation = targetRotation
                arrowContainer.scaleX = targetScale
                arrowContainer.scaleY = targetScale
                targetIconView.alpha = targetIconAlpha
                applyTargetIconTint()
                return
            }

            animateColor(currentArrowBackgroundColor, targetArrowBackground) { setArrowBackgroundColor(it) }
            animateColor(currentArrowTintColor, targetArrowTint) { setArrowTintColor(it) }
            animateColor(currentTitleColor, targetTitle) { color ->
                setTitleColor(color)
                applyTargetIconTint()
            }
            arrowImageView
                .animate()
                .rotation(targetRotation)
                .setDuration(220L)
                .start()
            arrowContainer
                .animate()
                .scaleX(targetScale)
                .scaleY(targetScale)
                .setDuration(220L)
                .start()
            targetIconView
                .animate()
                .alpha(targetIconAlpha)
                .setDuration(180L)
                .start()
        }

        private fun animateColor(
            fromColor: Int,
            toColor: Int,
            update: (Int) -> Unit,
        ) {
            ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 220L
                addUpdateListener {
                    val color = argbEvaluator.evaluate(it.animatedFraction, fromColor, toColor) as Int
                    update(color)
                }
                start()
            }
        }

        private fun setArrowBackgroundColor(color: Int) {
            currentArrowBackgroundColor = color
            arrowBackground.setColor(color)
        }

        private fun setArrowTintColor(color: Int) {
            currentArrowTintColor = color
            arrowImageView.imageTintList = ColorStateList.valueOf(color)
        }

        private fun setTitleColor(color: Int) {
            currentTitleColor = color
            titleView.setTextColor(color)
        }

        private fun applyTargetIconTint() {
            if (targetIconUsesTemplate) {
                targetIconView.imageTintList = ColorStateList.valueOf(currentTitleColor)
            }
        }

        private fun paletteFor(theme: PrefConstants.ThemeValue): Palette =
            when (theme) {
                PrefConstants.ThemeValue.SEPIA ->
                    Palette(
                        cardColor = ContextCompat.getColor(context, R.color.item_background_sepia),
                        borderColor = ContextCompat.getColor(context, R.color.row_border_sepia),
                        inactiveArrowBackgroundColor = Color.rgb(229, 217, 200),
                        inactiveArrowColor = ContextCompat.getColor(context, R.color.button_text_sepia),
                        inactiveTitleColor = ContextCompat.getColor(context, R.color.text_sepia),
                        activeArrowBackgroundColor = ContextCompat.getColor(context, R.color.linkblue_sepia),
                        activeTitleColor = ContextCompat.getColor(context, R.color.linkblue_sepia),
                    )
                PrefConstants.ThemeValue.DARK ->
                    Palette(
                        cardColor = Color.rgb(58, 58, 60),
                        borderColor = Color.rgb(81, 81, 83),
                        inactiveArrowBackgroundColor = Color.rgb(85, 85, 87),
                        inactiveArrowColor = ContextCompat.getColor(context, R.color.gray85),
                        inactiveTitleColor = Color.rgb(242, 242, 247),
                        activeArrowBackgroundColor = Color.rgb(90, 143, 211),
                        activeTitleColor = Color.rgb(140, 191, 255),
                    )
                PrefConstants.ThemeValue.BLACK ->
                    Palette(
                        cardColor = Color.rgb(37, 37, 39),
                        borderColor = Color.rgb(58, 58, 60),
                        inactiveArrowBackgroundColor = Color.rgb(68, 68, 70),
                        inactiveArrowColor = ContextCompat.getColor(context, R.color.gray85),
                        inactiveTitleColor = Color.rgb(242, 242, 247),
                        activeArrowBackgroundColor = Color.rgb(90, 143, 211),
                        activeTitleColor = Color.rgb(157, 202, 255),
                    )
                else ->
                    Palette(
                        cardColor = ContextCompat.getColor(context, R.color.white),
                        borderColor = ContextCompat.getColor(context, R.color.gray85),
                        inactiveArrowBackgroundColor = Color.rgb(220, 226, 234),
                        inactiveArrowColor = ContextCompat.getColor(context, R.color.button_text),
                        inactiveTitleColor = ContextCompat.getColor(context, R.color.text),
                        activeArrowBackgroundColor = ContextCompat.getColor(context, R.color.linkblue),
                        activeTitleColor = ContextCompat.getColor(context, R.color.linkblue),
                    )
            }

        private fun dp(value: Int): Int = UIUtils.dp2px(context, value)

        private data class Palette(
            val cardColor: Int,
            val borderColor: Int,
            val inactiveArrowBackgroundColor: Int,
            val inactiveArrowColor: Int,
            val inactiveTitleColor: Int,
            val activeArrowBackgroundColor: Int,
            val activeTitleColor: Int,
        )
    }
