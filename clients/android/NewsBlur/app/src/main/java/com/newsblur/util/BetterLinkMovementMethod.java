package com.newsblur.util;

import android.graphics.RectF;
import android.text.Layout;
import android.text.Spannable;
import android.text.Spanned;
import android.text.method.LinkMovementMethod;
import android.text.style.ClickableSpan;
import android.text.style.URLSpan;
import android.text.util.Linkify;
import android.view.MotionEvent;
import android.widget.TextView;

public class BetterLinkMovementMethod extends LinkMovementMethod {

    private static final int LINKIFY_NONE = -2;

    private OnLinkClickListener onLinkClickListener;
    private final RectF touchedLineBounds = new RectF();
    private ClickableSpan clickableSpanUnderTouchOnActionDown;
    private int activeTextViewHashcode;

    public interface OnLinkClickListener {
        /**
         * @param textView The TextView on which a click was registered.
         * @param url      The clicked URL.
         * @return True if this click was handled. False to let Android handle the URL.
         */
        boolean onClick(TextView textView, String url);
    }

    /**
     * Return a new instance of BetterLinkMovementMethod.
     */
    public static BetterLinkMovementMethod newInstance() {
        return new BetterLinkMovementMethod();
    }

    /**
     * @param linkifyMask One of {@link Linkify#ALL}, {@link Linkify#PHONE_NUMBERS}, {@link Linkify#MAP_ADDRESSES},
     *                    {@link Linkify#WEB_URLS} and {@link Linkify#EMAIL_ADDRESSES}.
     * @param textViews   The TextViews on which a {@link BetterLinkMovementMethod} should be registered.
     * @return The registered {@link BetterLinkMovementMethod} on the TextViews.
     */
    public static BetterLinkMovementMethod linkify(int linkifyMask, TextView... textViews) {
        BetterLinkMovementMethod movementMethod = newInstance();
        for (TextView textView : textViews) {
            addLinks(linkifyMask, movementMethod, textView);
        }
        return movementMethod;
    }

    private BetterLinkMovementMethod() {
    }

    /**
     * Set a listener that will get called whenever any link is clicked on the TextView.
     */
    public void setOnLinkClickListener(OnLinkClickListener clickListener) {
        this.onLinkClickListener = clickListener;
    }

    private static void addLinks(int linkifyMask, BetterLinkMovementMethod movementMethod, TextView textView) {
        textView.setMovementMethod(movementMethod);
        if (linkifyMask != LINKIFY_NONE) {
            Linkify.addLinks(textView, linkifyMask);
        }
    }

    @Override
    public boolean onTouchEvent(final TextView textView, Spannable text, MotionEvent event) {
        if (activeTextViewHashcode != textView.hashCode()) {
            // Bug workaround: TextView stops calling onTouchEvent() once any URL is highlighted.
            // A hacky solution is to reset any "autoLink" property set in XML. But we also want
            // to do this once per TextView.
            activeTextViewHashcode = textView.hashCode();
            textView.setAutoLinkMask(0);
        }

        final ClickableSpan clickableSpanUnderTouch = findClickableSpanUnderTouch(textView, text, event);
        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            clickableSpanUnderTouchOnActionDown = clickableSpanUnderTouch;
        }
        final boolean touchStartedOverAClickableSpan = clickableSpanUnderTouchOnActionDown != null;

        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:

            case MotionEvent.ACTION_MOVE:
                return touchStartedOverAClickableSpan;

            case MotionEvent.ACTION_UP:
                // Register a click only if the touch started and ended on the same URL.
                if (touchStartedOverAClickableSpan && clickableSpanUnderTouch == clickableSpanUnderTouchOnActionDown) {
                    dispatchUrlClick(textView, clickableSpanUnderTouch);
                }
                cleanupOnTouchUp();

                // Consume this event even if we could not find any spans to avoid letting Android handle this event.
                // Android's TextView implementation has a bug where links get clicked even when there is no more text
                // next to the link and the touch lies outside its bounds in the same direction.
                return touchStartedOverAClickableSpan;

            case MotionEvent.ACTION_CANCEL:
                cleanupOnTouchUp();
                return false;

            default:
                return false;
        }
    }

    private void cleanupOnTouchUp() {
        clickableSpanUnderTouchOnActionDown = null;
    }

    /**
     * Determines the touched location inside the TextView's text and returns the ClickableSpan found under it (if any).
     *
     * @return The touched ClickableSpan or null.
     */
    protected ClickableSpan findClickableSpanUnderTouch(TextView textView, Spannable text, MotionEvent event) {
        // So we need to find the location in text where touch was made, regardless of whether the TextView
        // has scrollable text. That is, not the entire text is currently visible.
        int touchX = (int) event.getX();
        int touchY = (int) event.getY();

        // Ignore padding.
        touchX -= textView.getTotalPaddingLeft();
        touchY -= textView.getTotalPaddingTop();

        // Account for scrollable text.
        touchX += textView.getScrollX();
        touchY += textView.getScrollY();

        final Layout layout = textView.getLayout();
        final int touchedLine = layout.getLineForVertical(touchY);
        final int touchOffset = layout.getOffsetForHorizontal(touchedLine, touchX);

        touchedLineBounds.left = layout.getLineLeft(touchedLine);
        touchedLineBounds.top = layout.getLineTop(touchedLine);
        touchedLineBounds.right = layout.getLineWidth(touchedLine) + touchedLineBounds.left;
        touchedLineBounds.bottom = layout.getLineBottom(touchedLine);

        if (touchedLineBounds.contains(touchX, touchY)) {
            // Find a ClickableSpan that lies under the touched area.
            final Object[] spans = text.getSpans(touchOffset, touchOffset, ClickableSpan.class);
            for (final Object span : spans) {
                if (span instanceof ClickableSpan) {
                    return (ClickableSpan) span;
                }
            }
            // No ClickableSpan found under the touched location.

        }
        return null;
    }

    protected void dispatchUrlClick(TextView textView, ClickableSpan clickableSpan) {
        ClickableSpanWithText clickableSpanWithText = ClickableSpanWithText.ofSpan(textView, clickableSpan);
        boolean handled = onLinkClickListener != null && onLinkClickListener.onClick(textView, clickableSpanWithText.text());

        if (!handled) {
            // Let Android handle this click.
            clickableSpanWithText.span().onClick(textView);
        }
    }

    /**
     * A wrapper to support all {@link ClickableSpan}s that may or may not provide URLs.
     */
    protected static class ClickableSpanWithText {
        private ClickableSpan span;
        private String text;

        protected static ClickableSpanWithText ofSpan(TextView textView, ClickableSpan span) {
            Spanned s = (Spanned) textView.getText();
            String text;
            if (span instanceof URLSpan) {
                text = ((URLSpan) span).getURL();
            } else {
                int start = s.getSpanStart(span);
                int end = s.getSpanEnd(span);
                text = s.subSequence(start, end).toString();
            }
            return new ClickableSpanWithText(span, text);
        }

        protected ClickableSpanWithText(ClickableSpan span, String text) {
            this.span = span;
            this.text = text;
        }

        protected ClickableSpan span() {
            return span;
        }

        protected String text() {
            return text;
        }
    }
}
