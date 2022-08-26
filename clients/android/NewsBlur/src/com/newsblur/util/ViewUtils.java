package com.newsblur.util;

import android.content.Context;
import android.content.Intent;
import android.os.PowerManager;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageView;

import com.newsblur.R;
import com.newsblur.activity.Profile;
import com.newsblur.view.FlowLayout;

public class ViewUtils {

    private ViewUtils() {} // util class - no instances

	public static ImageView createSharebarImage(final Context context, final String photoUrl, final String userId, ImageLoader iconLoader) {
		ImageView image = new ImageView(context);
		int imageLength = UIUtils.dp2px(context, 15);
		image.setMaxHeight(imageLength);
		image.setMaxWidth(imageLength);
		image.setClipToOutline(true);
		image.setBackgroundResource(R.drawable.shape_rounded_corners_4dp);

		FlowLayout.LayoutParams imageParameters = new FlowLayout.LayoutParams(5, 5);

		imageParameters.height = imageLength;
		imageParameters.width = imageLength;

		image.setMaxHeight(imageLength);
		image.setMaxWidth(imageLength);

		image.setLayoutParams(imageParameters);
		iconLoader.displayImage(photoUrl, image);
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

    /**
     * see if Power Save mode is enabled on the device and the UI should disable animations
     * or other extra features.
     */
    public static boolean isPowerSaveMode(Context context) {
        PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        return pm.isPowerSaveMode();
    }

    public static void setViewElevation(View v, float elevationDP) {
        float elevationPX = UIUtils.dp2px(v.getContext(), elevationDP);
        v.setElevation(elevationPX);
    }

}
