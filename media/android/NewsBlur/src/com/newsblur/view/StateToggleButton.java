package com.newsblur.view;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageView;
import android.widget.LinearLayout;

import com.newsblur.R;
import com.newsblur.util.AppConstants;
import com.newsblur.util.UIUtils;

public class StateToggleButton extends LinearLayout implements OnClickListener {

	private int CURRENT_STATE = AppConstants.STATE_ALL;

	private Context context;
	private StateChangedListener stateChangedListener;
	private ImageView imageStateOne;
	private ImageView imageStateTwo;
	private ImageView imageStateThree;

	public StateToggleButton(Context context, AttributeSet art) {
		super(context, art);
		this.context = context;
		setupContents();
	}

	public void setStateListener(final StateChangedListener stateChangedListener) {
		this.stateChangedListener = stateChangedListener;
	}

	public void setupContents() {
		final int length = UIUtils.convertDPsToPixels(context, 25);
		final int marginSide = UIUtils.convertDPsToPixels(context, 35);
		final int marginTop = UIUtils.convertDPsToPixels(context, 5);

		imageStateOne = new ImageView(context);
		imageStateOne.setId(AppConstants.STATE_ALL);
		imageStateOne.setImageResource(R.drawable.negative_count_rect);
		imageStateOne.setLayoutParams(new LayoutParams(length, length));

		LayoutParams centerParams = new LayoutParams(length, length);
		centerParams.setMargins(marginSide, marginTop, marginSide, marginTop);
		imageStateTwo = new ImageView(context);
		imageStateTwo.setId(AppConstants.STATE_SOME);
		imageStateTwo.setImageResource(R.drawable.neutral_count_rect);
		imageStateTwo.setLayoutParams(centerParams);

		imageStateThree = new ImageView(context);
		imageStateThree.setId(AppConstants.STATE_BEST);
		imageStateThree.setImageResource(R.drawable.positive_count_rect);
		imageStateThree.setLayoutParams(new LayoutParams(length, length));

		imageStateOne.setOnClickListener(this);
		imageStateTwo.setOnClickListener(this);
		imageStateThree.setOnClickListener(this);

		this.addView(imageStateOne);
		this.addView(imageStateTwo);
		this.addView(imageStateThree);

		changeState(CURRENT_STATE);
	}

	@Override
	public void onClick(View v) {
		changeState(v.getId());
	}

	public void changeState(final int state) {
		switch (state) {
			case AppConstants.STATE_ALL:
				imageStateOne.setAlpha(255);
				imageStateTwo.setAlpha(125);
				imageStateThree.setAlpha(125);
				break;
			case AppConstants.STATE_SOME:
				imageStateOne.setAlpha(125);
				imageStateTwo.setAlpha(255);
				imageStateThree.setAlpha(125);
				break;
			case AppConstants.STATE_BEST:
				imageStateOne.setAlpha(125);
				imageStateTwo.setAlpha(125);
				imageStateThree.setAlpha(255);
				break;	
		}
		
		CURRENT_STATE = state;

		if (stateChangedListener != null) {
			stateChangedListener.changedState(CURRENT_STATE);
		}
	}

	public interface StateChangedListener {
		public void changedState(int state);
	}

}
