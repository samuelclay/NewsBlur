package com.newsblur.view

import android.animation.ValueAnimator
import android.view.View
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.view.animation.AnimationSet
import android.view.animation.OvershootInterpolator
import android.view.animation.ScaleAnimation
import android.view.animation.TranslateAnimation

/** ReaderMotion.kt animates presentation without changing layout, swipe offsets, or theme colors. */
object ReaderMotion {
    private val departures = java.util.WeakHashMap<View, ValueAnimator>()

    /** ReaderMotion.kt keeps semantic visibility immediate and fades only a noninteractive drawing copy. */
    @JvmStatic fun visibility(view: View, visibility: Int) {
        if (view.visibility == visibility) return
        departures.remove(view)?.cancel()
        if (visibility == View.VISIBLE) {
            view.visibility = visibility
            enter(view)
            return
        }
        val parent = view.parent as? android.view.ViewGroup
        val bitmap = if (view.isShown && parent != null && view.width > 0 && view.height > 0 &&
            view.width.toLong() * view.height <= 1_000_000 && ValueAnimator.areAnimatorsEnabled() &&
            !com.newsblur.util.ViewUtils.isPowerSaveMode(view.context)) {
            departureSnapshot(view)
        } else null
        if (bitmap != null && parent != null) {
            val ghost = android.graphics.drawable.BitmapDrawable(view.resources, bitmap)
            val left = view.left - parent.scrollX
            val top = view.top - parent.scrollY
            ghost.setBounds(left, top, left + view.width, top + view.height)
            parent.overlay.add(ghost)
            val animation = ValueAnimator.ofFloat(0f, 1f)
            departures[view] = animation
            animation.duration = 220
            animation.addUpdateListener {
                val fraction = it.animatedValue as Float
                ghost.alpha = ((1f - fraction) * 255).toInt()
                val lift = (8 * view.resources.displayMetrics.density * fraction).toInt()
                ghost.setBounds(left, top - lift, left + bitmap.width, top + bitmap.height - lift)
            }
            animation.addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animator: android.animation.Animator) {
                    parent.overlay.remove(ghost)
                    if (departures[view] === animator) departures.remove(view)
                }
            })
            animation.start()
        }
        view.clearAnimation()
        view.visibility = visibility
    }

    private fun departureSnapshot(view: View): android.graphics.Bitmap? {
        var bitmap: android.graphics.Bitmap? = null
        return try {
            bitmap = android.graphics.Bitmap.createBitmap(view.width, view.height, android.graphics.Bitmap.Config.ARGB_8888)
            view.draw(android.graphics.Canvas(bitmap))
            bitmap
        } catch (_: OutOfMemoryError) {
            // ReaderMotion.kt treats the drawing copy as optional; hiding the real view must still succeed.
            bitmap?.recycle()
            null
        }
    }

    @JvmStatic fun canEnter(view: View): Boolean {
        if (!view.isAttachedToWindow || !view.isShown || view.windowVisibility != View.VISIBLE ||
            !ValueAnimator.areAnimatorsEnabled() || com.newsblur.util.ViewUtils.isPowerSaveMode(view.context)) return false
        var ancestor: View? = view
        while (ancestor != null) {
            if (ancestor.visibility != View.VISIBLE || ancestor.alpha <= 0f) return false
            ancestor = ancestor.parent as? View
        }
        return true
    }

    @JvmStatic fun enter(view: View, delay: Long = 0, distance: Float = 16f): Boolean {
        if (!canEnter(view)) return false
        // ReaderMotion.kt counts restored rows as presented beneath the whole-screen theme crossfade.
        if (ThemeTransition.isRevealing(view)) return true
        view.startAnimation(AnimationSet(false).apply {
            addAnimation(AlphaAnimation(0f, 1f).apply { duration = 240 })
            addAnimation(TranslateAnimation(0f, 0f, distance * view.resources.displayMetrics.density, 0f).apply {
                duration = 350
                interpolator = OvershootInterpolator(.7f)
            })
            startOffset = delay.coerceAtMost(175)
        })
        return true
    }

    @JvmStatic fun pop(view: View) {
        if (!view.isAttachedToWindow || !ValueAnimator.areAnimatorsEnabled() || com.newsblur.util.ViewUtils.isPowerSaveMode(view.context)) return
        view.startAnimation(ScaleAnimation(.86f, 1f, .86f, 1f,
            Animation.RELATIVE_TO_SELF, .5f, Animation.RELATIVE_TO_SELF, .5f).apply {
            duration = 320
            interpolator = OvershootInterpolator(3f)
        })
    }

    @JvmStatic fun cascade(views: List<View>) {
        views.filter { it.visibility == View.VISIBLE }.forEachIndexed { index, view ->
            enter(view, index * 30L, 8f)
        }
    }

    @JvmStatic fun refreshFinished(container: android.view.ViewGroup) {
        if (!container.isAttachedToWindow || !ValueAnimator.areAnimatorsEnabled()) return
        val check = android.widget.ImageView(container.context)
        check.setImageResource(com.newsblur.R.drawable.ic_checkmark)
        val color = android.util.TypedValue()
        container.context.theme.resolveAttribute(android.R.attr.textColorPrimary, color, true)
        check.imageTintList = android.content.res.ColorStateList.valueOf(
            if (color.resourceId != 0) androidx.core.content.ContextCompat.getColor(container.context, color.resourceId) else color.data)
        val size = (24 * container.resources.displayMetrics.density).toInt()
        check.layout(container.width / 2 - size / 2, size, container.width / 2 + size / 2, size * 2)
        container.overlay.add(check)
        pop(check)
        container.postDelayed({ container.overlay.remove(check) }, 450)
    }
}
