package com.newsblur.fragment;

import java.io.Serializable;
import java.util.Map;

import android.os.Bundle;
import android.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;
import butterknife.OnClick;

import com.newsblur.R;
import com.newsblur.domain.Classifier;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;

public class ClassifierDialogFragment extends DialogFragment {

	private static final String KEY = "key";
	private static final String FEED_ID = "feed_id";
	private static final String TYPE = "type";
	private static final String CALLBACK = "callback";
	private static final String CLASSIFIER = "classifier";

    @Bind(R.id.tag_negative) ImageView classifyNegative;
    @Bind(R.id.tag_positive) ImageView classifyPositive;
    @Bind(R.id.dialog_message) TextView message;

	private String key, feedId;
	private Classifier classifier;
	private int classifierType;

	private TagUpdateCallback tagCallback;
    private Map<String,Integer> typeHashMap;

	public static ClassifierDialogFragment newInstance(TagUpdateCallback callbackInterface, final String feedId, final Classifier classifier, final String key, final int classifierType) {
		ClassifierDialogFragment frag = new ClassifierDialogFragment();
		Bundle args = new Bundle();
		args.putString(KEY, key);
		args.putString(FEED_ID, feedId);
		args.putSerializable(CALLBACK, callbackInterface);
		args.putInt(TYPE, classifierType);
		args.putSerializable(CLASSIFIER, classifier);
		frag.setArguments(args);
		return frag;
	}	

	@Override
	public void onCreate(Bundle savedInstanceState) {
        if (PrefsUtils.isLightThemeSelected(getActivity())) {
            setStyle(DialogFragment.STYLE_NO_TITLE, R.style.classifyDialog);
        } else {
            setStyle(DialogFragment.STYLE_NO_TITLE, R.style.darkClassifyDialog);
        }

		feedId = getArguments().getString(FEED_ID);
		key = getArguments().getString(KEY);
		classifierType = getArguments().getInt(TYPE);
		classifier = (Classifier) getArguments().getSerializable(CLASSIFIER);
		tagCallback = (TagUpdateCallback) getArguments().getSerializable(CALLBACK);

		super.onCreate(savedInstanceState);
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle bundle) {
		View v = inflater.inflate(R.layout.fragment_classify_dialog, container, false);
        ButterKnife.bind(this, v);

		typeHashMap = classifier.getMapForType(classifierType);

		if (typeHashMap != null && typeHashMap.containsKey(key)) {
			switch (typeHashMap.get(key)) {
			case Classifier.LIKE:
				classifyPositive.setImageResource(R.drawable.tag_positive_already);
				break;
			case Classifier.DISLIKE:
				classifyNegative.setImageResource(R.drawable.tag_negative_already);
				break;	
			}
		} 

		message.setText(key);

		return v;
	}

    @OnClick(R.id.tag_negative) void onClickNegative() {
        int classifierAction = (typeHashMap.containsKey(key) && typeHashMap.get(key) == Classifier.DISLIKE) ? Classifier.CLEAR_DISLIKE : Classifier.DISLIKE;
        FeedUtils.updateClassifier(feedId, key, classifier, classifierType, classifierAction, getActivity());
        tagCallback.updateTagView(key, classifierType,classifierAction);
        ClassifierDialogFragment.this.dismiss();
    }

    @OnClick(R.id.tag_positive) void onClickPositive() {
        int classifierAction = (typeHashMap.containsKey(key) && typeHashMap.get(key) == Classifier.LIKE) ? Classifier.CLEAR_LIKE : Classifier.LIKE;
        FeedUtils.updateClassifier(feedId, key, classifier, classifierType, classifierAction, getActivity());
        tagCallback.updateTagView(key, classifierType,classifierAction);
        ClassifierDialogFragment.this.dismiss();
    }

    @OnClick(R.id.dialog_message) void onClickNeutral() {
        FeedUtils.updateClassifier(feedId, key, classifier, classifierType, Classifier.CLEAR_LIKE, getActivity());
        tagCallback.updateTagView(key, classifierType, Classifier.CLEAR_LIKE);	
        ClassifierDialogFragment.this.dismiss();
    }

	
	public interface TagUpdateCallback extends Serializable{
		public void updateTagView(String value, int classifierType, int classifierAction);
	}

}
