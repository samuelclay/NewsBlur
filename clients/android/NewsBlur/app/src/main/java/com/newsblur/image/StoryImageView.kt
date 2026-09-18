package com.newsblur.image

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.VelocityTracker
import android.view.View
import android.view.ViewConfiguration
import android.view.accessibility.AccessibilityNodeInfo
import kotlin.math.hypot
import kotlin.math.max

class StoryImageView(
    context: Context,
    private val source: StoryImageSource,
) : View(context) {
    val viewport = ImageViewport()
    var bitmap: Bitmap? = null
        set(value) {
            field = value
            invalidate()
        }
    var onDismiss: () -> Unit = {}
    var onDrag: (Float) -> Unit = {}
    var onGeometryChanged: () -> Unit = {}
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val density = resources.displayMetrics.density
    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private var downX = 0f
    private var downY = 0f
    private var lastX = 0f
    private var lastY = 0f
    private var dragX = 0f
    private var dragY = 0f
    private var multiTouch = false
    private var dragging = false
    private var panning = false
    private var velocity: VelocityTracker? = null
    private var animation: ValueAnimator? = null
    private val scaleDetector =
        ScaleGestureDetector(
            context,
            object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
                override fun onScale(detector: ScaleGestureDetector): Boolean {
                    viewport.scaleTo(viewport.zoom * detector.scaleFactor, detector.focusX, detector.focusY)
                    update()
                    return true
                }
            },
        ).apply { isQuickScaleEnabled = false }
    private val taps =
        GestureDetector(
            context,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onDown(e: MotionEvent) = true

                override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                    performClick()
                    return true
                }

                override fun onDoubleTap(e: MotionEvent): Boolean {
                    animateZoom(if (viewport.isZoomed) 1f else minOf(3f, viewport.maxZoom), e.x, e.y)
                    return true
                }
            },
        )

    init {
        contentDescription = source.title
        isFocusable = true
        isClickable = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    override fun onSizeChanged(
        w: Int,
        h: Int,
        oldw: Int,
        oldh: Int,
    ) {
        animation?.cancel()
        resetDrag()
        viewport.layout(w.toFloat(), h.toFloat(), source.naturalWidth * density, source.naturalHeight * density)
        update()
        onGeometryChanged()
    }

    fun imageRect(): RectF {
        val distance = hypot(dragX, dragY)
        val dragScale = max(0.75f, 1f - distance / max(width, height).coerceAtLeast(1) * 0.35f)
        val w = viewport.fittedWidth * viewport.zoom * dragScale
        val h = viewport.fittedHeight * viewport.zoom * dragScale
        val cx = width / 2f + viewport.panX + dragX
        val cy = height / 2f + viewport.panY + dragY
        return RectF(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
    }

    override fun onDraw(canvas: Canvas) {
        bitmap?.let { canvas.drawBitmap(it, null, imageRect(), paint) }
    }

    override fun performClick(): Boolean {
        super.performClick()
        if (viewport.isZoomed) animateZoom(1f, width / 2f, height / 2f)
        return true
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) {
            animation?.cancel()
            downX = event.x
            downY = event.y
            lastX = event.x
            lastY = event.y
            multiTouch = false
            dragging = false
            panning = viewport.isZoomed
            velocity?.recycle()
            velocity = VelocityTracker.obtain()
        }
        velocity?.addMovement(event)
        if (event.pointerCount > 1) {
            multiTouch = true
            resetDrag()
        }
        scaleDetector.onTouchEvent(event)
        taps.onTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_MOVE ->
                if (!multiTouch && !scaleDetector.isInProgress && animation?.isRunning != true) {
                    val dx = event.x - downX
                    val dy = event.y - downY
                    if (hypot(dx, dy) > slop) dragging = true
                    if (dragging) {
                        if (panning || viewport.isZoomed) {
                            viewport.pan(event.x - lastX, event.y - lastY)
                        } else {
                            dragX = dx
                            dragY = dy
                            onDrag((hypot(dx, dy) / (320 * density)).coerceIn(0f, 0.85f))
                        }
                        update()
                    }
                }
            MotionEvent.ACTION_UP -> {
                velocity?.computeCurrentVelocity(1000)
                if (dragging &&
                    !multiTouch &&
                    !panning &&
                    !viewport.isZoomed &&
                    ImageViewport.shouldDismiss(
                        dragX / density,
                        dragY / density,
                        (velocity?.xVelocity ?: 0f) / density,
                        (velocity?.yVelocity ?: 0f) / density,
                    )
                ) {
                    onDismiss()
                } else if (dragX != 0f || dragY != 0f) {
                    restoreDrag()
                }
                velocity?.recycle()
                velocity = null
            }
            MotionEvent.ACTION_CANCEL -> {
                restoreDrag()
                velocity?.recycle()
                velocity = null
            }
        }
        lastX = event.x
        lastY = event.y
        return true
    }

    private fun animateZoom(
        target: Float,
        x: Float,
        y: Float,
    ) {
        animation?.cancel()
        resetDrag()
        animation =
            ValueAnimator.ofFloat(viewport.zoom, target).apply {
                duration = 220
                addUpdateListener {
                    viewport.scaleTo(it.animatedValue as Float, x, y)
                    update()
                }
                start()
            }
    }

    private fun restoreDrag() {
        animation?.cancel()
        val x = dragX
        val y = dragY
        animation =
            ValueAnimator.ofFloat(1f, 0f).apply {
                duration = 220
                addUpdateListener {
                    val fraction = it.animatedValue as Float
                    dragX = x * fraction
                    dragY = y * fraction
                    onDrag((hypot(dragX, dragY) / (320 * density)).coerceIn(0f, 0.85f))
                    invalidate()
                }
                start()
            }
    }

    private fun resetDrag() {
        dragX = 0f
        dragY = 0f
        onDrag(0f)
    }

    private fun update() {
        androidx.core.view.ViewCompat
            .setStateDescription(this, if (viewport.isZoomed) "Zoomed" else "Fitted")
        invalidate()
    }

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.addAction(AccessibilityNodeInfo.AccessibilityAction(AccessibilityNodeInfo.ACTION_CLICK, "Fit image to screen"))
        info.addAction(AccessibilityNodeInfo.AccessibilityAction(AccessibilityNodeInfo.ACTION_LONG_CLICK, "Zoom image"))
    }

    override fun performAccessibilityAction(
        action: Int,
        arguments: android.os.Bundle?,
    ): Boolean {
        if (action == AccessibilityNodeInfo.ACTION_LONG_CLICK) {
            animateZoom(if (viewport.isZoomed) 1f else 3f, width / 2f, height / 2f)
            return true
        }
        return super.performAccessibilityAction(action, arguments)
    }

    override fun onDetachedFromWindow() {
        animation?.cancel()
        velocity?.recycle()
        velocity = null
        super.onDetachedFromWindow()
    }
}
