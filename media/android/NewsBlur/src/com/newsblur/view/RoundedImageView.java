package com.newsblur.view;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Path;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.widget.ImageView;

public class RoundedImageView extends ImageView {

	private Path clipPath;

	public RoundedImageView(Context context) {
		super(context);
		clipPath = new Path();
	}

	public RoundedImageView(Context context, AttributeSet attrs) {
		super(context, attrs);
		clipPath = new Path();
	}

	// TODO: Fix this to use proper anti-aliasing for the corners
	protected void onDraw(Canvas canvas) {
		clipPath.addRoundRect(new RectF(0, 0, getWidth(), getHeight()), getWidth() / 12, getWidth() / 12, Path.Direction.CW);
		canvas.clipPath(clipPath);
		super.onDraw(canvas);
	};


}
