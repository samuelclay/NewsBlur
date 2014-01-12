package com.newsblur.fragment;

import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.RadioButton;

import com.newsblur.R;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.DefaultFeedViewChangedListener;

/**
 * Created by mark on 09/01/2014.
 */
public class DefaultFeedViewDialogFragment extends DialogFragment implements View.OnClickListener {

    private static String CURRENT_VIEW = "currentView";
    private DefaultFeedView currentValue;

    public static DefaultFeedViewDialogFragment newInstance(DefaultFeedView currentValue) {
        DefaultFeedViewDialogFragment dialog = new DefaultFeedViewDialogFragment();
        Bundle args = new Bundle();
        args.putSerializable(CURRENT_VIEW, currentValue);
        dialog.setArguments(args);

        return dialog;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
        currentValue = (DefaultFeedView) getArguments().getSerializable(CURRENT_VIEW);
        View v = inflater.inflate(R.layout.defaultfeedview_dialog, null);
        RadioButton storyButton = (RadioButton) v.findViewById(R.id.radio_story);
        storyButton.setOnClickListener(this);
        storyButton.setChecked(currentValue == DefaultFeedView.STORY);
        RadioButton textButton = (RadioButton) v.findViewById(R.id.radio_text);
        textButton.setOnClickListener(this);
        textButton.setChecked(currentValue == DefaultFeedView.TEXT);

        getDialog().getWindow().setFlags(WindowManager.LayoutParams.FLAG_DITHER, WindowManager.LayoutParams.FLAG_DITHER);
        getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
        getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;

        return v;
    }

    @Override
    public void onClick(View v) {
        DefaultFeedViewChangedListener listener = (DefaultFeedViewChangedListener)getActivity();
        if (v.getId() == R.id.radio_story) {
            if (currentValue == DefaultFeedView.TEXT) {
                listener.defaultFeedViewChanged(DefaultFeedView.STORY);
            }
        } else {
            if (currentValue == DefaultFeedView.STORY) {
                listener.defaultFeedViewChanged(DefaultFeedView.TEXT);
            }
        }

        dismiss();
    }
}
