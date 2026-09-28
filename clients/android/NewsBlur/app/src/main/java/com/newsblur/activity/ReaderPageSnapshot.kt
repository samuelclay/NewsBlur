package com.newsblur.activity

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.core.view.doOnPreDraw
import androidx.viewpager.widget.ViewPager
import com.newsblur.R
import com.newsblur.databinding.ActivityReadingBinding

/** Reading.kt retains one window-rendered viewport, including WebView, while its bounded pager prepares a jump. */
internal class ReaderPageSnapshot(
    private val activity: Activity,
    private val binding: ActivityReadingBinding,
    private val pager: ViewPager,
) {
    private var generation = 0
    private var bitmap: Bitmap? = null
    private var snapshot: ImageView? = null

    fun capture(completion: (Boolean) -> Unit) {
        val requestGeneration = ++generation
        // ReaderPageSnapshot.kt captures after layout/draw so a just-finished slide cannot leave a partial snapshot.
        binding.content.doOnPreDraw {
            binding.content.post {
                if (generation != requestGeneration) return@post
                val location = IntArray(2)
                binding.content.getLocationInWindow(location)
                val bounds = Rect(
                    location[0], location[1],
                    location[0] + binding.content.width, location[1] + binding.content.height,
                )
                val decor = activity.window.decorView
                if (!decor.isAttachedToWindow || !bounds.intersect(0, 0, decor.width, decor.height)) {
                    completion(false)
                    return@post
                }
                val captured = try {
                    Bitmap.createBitmap(bounds.width(), bounds.height(), Bitmap.Config.ARGB_8888)
                } catch (_: OutOfMemoryError) {
                    completion(false)
                    return@post
                }
                try {
                    PixelCopy.request(activity.window, bounds, captured, { result ->
                        if (generation != requestGeneration || result != PixelCopy.SUCCESS) {
                            captured.recycle()
                            if (generation == requestGeneration) completion(false)
                            return@request
                        }
                        bitmap = captured
                        snapshot = ImageView(activity).apply {
                            scaleType = ImageView.ScaleType.FIT_XY
                            setImageBitmap(captured)
                            isClickable = true
                            contentDescription = activity.getString(R.string.loading)
                            binding.content.addView(
                                this,
                                FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT),
                            )
                        }
                        prepareReaderSurface(pager)
                        pager.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
                        completion(true)
                    }, Handler(Looper.getMainLooper()))
                } catch (_: IllegalArgumentException) {
                    captured.recycle()
                    completion(false)
                }
            }
        }
        binding.content.invalidate()
    }

    fun animate(direction: Int, completion: () -> Unit) {
        val distance = direction * binding.content.width.toFloat()
        pager.alpha = 1f
        pager.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
        if (distance == 0f) {
            completion()
            return
        }
        pager.translationX = distance
        binding.contentBottomOverlay.translationX = distance
        val interpolator = DecelerateInterpolator()
        snapshot?.animate()?.translationX(-distance)?.setDuration(180L)?.setInterpolator(interpolator)?.start()
        binding.contentBottomOverlay.animate().translationX(0f).setDuration(180L).setInterpolator(interpolator).start()
        pager.animate().translationX(0f).setDuration(180L).setInterpolator(interpolator).withEndAction(completion).start()
    }

    fun freezeForExit() {
        generation++
        snapshot?.animate()?.cancel()
        pager.animate().cancel()
        binding.contentBottomOverlay.animate().cancel()
    }

    fun release() {
        freezeForExit()
        pager.alpha = 1f
        pager.translationX = 0f
        pager.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
        binding.contentBottomOverlay.translationX = 0f
        snapshot?.let {
            it.setImageDrawable(null)
            binding.content.removeView(it)
        }
        snapshot = null
        bitmap?.recycle()
        bitmap = null
    }
}
