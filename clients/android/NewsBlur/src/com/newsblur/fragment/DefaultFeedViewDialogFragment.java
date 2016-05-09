package com.newsblur.fragment;

import android.os.Bundle;
import android.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.RadioButton;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.DefaultFeedViewChangedListener;

/**
 * Created by mark on 09/01/2014.
 */
public class DefaultFeedViewDialogFragment extends DialogFragment {

    private static String CURRENT_VIEW = "currentView";
    private DefaultFeedView currentValue;
    @Bind(R.id.radio_story) RadioButton storyButton;
    @Bind(R.id.radio_text) RadioButton textButton;

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
        ButterKnife.bind(this, v);

        storyButton.setChecked(currentValue == DefaultFeedView.STORY);
        textButton.setChecked(currentValue == DefaultFeedView.TEXT);

        getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
        getDialog().getWindow().getAttributes().gravity = Gravity.BOTTOM;

        return v;
    }

    @OnClick(R.id.radio_story) void selectStory() {
        if (currentValue != DefaultFeedView.STORY) {
            ((DefaultFeedViewChangedListener) getActivity()).defaultFeedViewChanged(DefaultFeedView.STORY);
        }
        dismiss();
    }
        
    @OnClick(R.id.radio_text) void selectText() {
        if (currentValue != DefaultFeedView.TEXT) {
            ((DefaultFeedViewChangedListener) getActivity()).defaultFeedViewChanged(DefaultFeedView.TEXT);
        }
        dismiss();
    }

}
