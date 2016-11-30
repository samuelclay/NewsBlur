package com.newsblur.util;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.PowerManager;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageView;

import com.newsblur.activity.Profile;
import com.newsblur.view.FlowLayout;

public class ViewUtils {

    private ViewUtils() {} // util class - no instances

	public static ImageView createSharebarImage(final Context context, final String photoUrl, final String userId) {
		ImageView image = new ImageView(context);
		int imageLength = UIUtils.dp2px(context, 15);
		image.setMaxHeight(imageLength);
		image.setMaxWidth(imageLength);
		
		FlowLayout.LayoutParams imageParameters = new FlowLayout.LayoutParams(5, 5);
		
		imageParameters.height = imageLength;
		imageParameters.width = imageLength;
		
		image.setMaxHeight(imageLength);
		image.setMaxWidth(imageLength);
		
		image.setLayoutParams(imageParameters);
		FeedUtils.iconLoader.displayImage(photoUrl, image, 10f, false);
		image.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View view) {
				Intent i = new Intent(context, Profile.class);
				i.putExtra(Profile.USER_ID, userId);
				context.startActivity(i);
			}
		});
		return image;
	}

    public static void showSystemUI(View view) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) return;
        // Some layout/drawing artifacts as we don't use the FLAG_LAYOUT flags but otherwise the overlays wouldn't appear
        // and the action bar would overlap the content
        view.setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE);
    }

    public static void hideSystemUI(View view) {
        view.setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE);
    }

    public static boolean isSystemUIHidden(View view) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) return false;
        return (view.getSystemUiVisibility() & View.SYSTEM_UI_FLAG_IMMERSIVE) != 0;
    }

    public static boolean immersiveViewExitedViaSystemGesture(View view) {
        return view.getSystemUiVisibility() == (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_IMMERSIVE);
    }

    /**
     * see if Power Save mode is enabled on the device and the UI should disable animations
     * or other extra features.
     */
    public static boolean isPowerSaveMode(Context context) {
        if (android.os.Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false;
        PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        return pm.isPowerSaveMode();
    }

    public static void setViewElevation(View v, float elevationDP) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return;
        float elevationPX = UIUtils.dp2px(v.getContext(), elevationDP);
        v.setElevation(elevationPX);
    }

}
