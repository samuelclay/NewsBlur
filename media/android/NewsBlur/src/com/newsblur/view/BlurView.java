package com.newsblur.view;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.BlurMaskFilter;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;

import com.newsblur.R;

public class BlurView extends View implements SensorEventListener {

	private static final String TAG = "BlurView";
	private Bitmap baseImage;
	private SensorManager mSensorManager;
	private Sensor mAccelerometer;
	private boolean mInitialized;
	private float mLastX;
	private float mLastY;
	private float NOISE = 2.0f;
	private float accelerometerValue = 1.5f;

	public BlurView(Context context, AttributeSet attributeSet) {
		super(context, attributeSet);
		baseImage = BitmapFactory.decodeResource(getResources(), R.drawable.logo);

		mInitialized = false;
		mSensorManager = (SensorManager) context.getSystemService(Context.SENSOR_SERVICE);
		mAccelerometer = mSensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
		mSensorManager.registerListener(this, mAccelerometer, SensorManager.SENSOR_DELAY_NORMAL);

	}

	@Override
	protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
		super.onMeasure(widthMeasureSpec, heightMeasureSpec);
		int parentWidth = MeasureSpec.getSize(widthMeasureSpec);
		int parentHeight = MeasureSpec.getSize(heightMeasureSpec);
		baseImage = Bitmap.createScaledBitmap(baseImage, parentWidth, parentHeight, false);
	}

	@Override
	protected void onAttachedToWindow() {
		super.onAttachedToWindow();
		Log.d(TAG, "Attached to window");
		
		mSensorManager.registerListener(this, mAccelerometer, SensorManager.SENSOR_DELAY_NORMAL);
	}

	@Override
	protected void onDetachedFromWindow() {
		Log.d(TAG, "Detached from window");
		super.onDetachedFromWindow();
		mSensorManager.unregisterListener(this);
	}

	@Override
	public void draw(Canvas canvas) {
		canvas.drawBitmap(otherBlur(baseImage), 0, 0, null);
	}

	private Bitmap otherBlur(Bitmap src) {

		int width = src.getWidth();
		int height = src.getHeight();

		BlurMaskFilter blurMaskFilter;
		Paint paintBlur = new Paint();

		Bitmap dest = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565);
		Canvas canvas = new Canvas(dest); 

		//Create background in White
		Bitmap alpha = src.extractAlpha();
		paintBlur.setColor(0xfffbe74d);
		canvas.drawBitmap(alpha, 0, 0, paintBlur);

		blurMaskFilter = new BlurMaskFilter(accelerometerValue * 3, BlurMaskFilter.Blur.OUTER);
		paintBlur.setMaskFilter(blurMaskFilter);
		canvas.drawBitmap(alpha, 0, 0, paintBlur);

		//Create inner blur
		blurMaskFilter = new BlurMaskFilter(accelerometerValue * 3, BlurMaskFilter.Blur.INNER);
		paintBlur.setMaskFilter(blurMaskFilter);
		canvas.drawBitmap(src, 0, 0, paintBlur);

		return dest;
	}



	@Override
	public void onAccuracyChanged(Sensor sensor, int accuracy) {

	}

	@Override
	public void onSensorChanged(SensorEvent event) {
		final float x = event.values[0];
		if (accelerometerValue - x > NOISE) {
			accelerometerValue += (x - accelerometerValue) / 3f;
			Log.d(TAG, "Sensor changed");
			postDelayed(new Runnable() {
				@Override
				public void run() {
					accelerometerValue = Math.abs(x);
					invalidate();
				}
			}, 200);
		}
	}
}