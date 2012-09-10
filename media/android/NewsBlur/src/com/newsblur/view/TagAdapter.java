package com.newsblur.view;

import android.app.Activity;
import android.content.Context;
import android.support.v4.app.FragmentManager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.domain.Classifier;
import com.newsblur.fragment.ClassifierDialogFragment;

public class TagAdapter extends BaseAdapter {

	private final String[] tags;
	private LayoutInflater inflater;
	private final Classifier classifier;
	private final String feedId;
	private final FragmentManager fragmentManager;

	public TagAdapter(Context context, FragmentManager fragmentManager, String feedId, Classifier classifier, String[] tags) {
		this.fragmentManager = fragmentManager;
		this.feedId = feedId;
		this.classifier = classifier;
		this.tags = tags;
		inflater = ((Activity) context).getLayoutInflater();
	}
	
	@Override
	public int getCount() {
		return tags.length;
	}

	@Override
	public String getItem(int position) {
		return tags[position];
	}

	@Override
	public long getItemId(int position) {
		return position;
	}

	@Override
	public View getView(int position, View convertView, ViewGroup parent) {
		final String tag = tags[position];
		
		View v = inflater.inflate(R.layout.tag_view, null);
		
		TextView tagText = (TextView) v.findViewById(R.id.tag_text);
		tagText.setText(tag);

		if (classifier != null && classifier.tags.containsKey(tag)) {
			switch (classifier.tags.get(tag)) {
			case Classifier.LIKE:
				tagText.setBackgroundResource(R.drawable.tag_background_positive);
				break;
			case Classifier.DISLIKE:
				tagText.setBackgroundResource(R.drawable.tag_background_negative);
				break;
			}
		}

		v.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View view) {
				ClassifierDialogFragment classifierFragment = ClassifierDialogFragment.newInstance(feedId, classifier, tag, Classifier.TAG);
				classifierFragment.show(fragmentManager, "dialog");
			}
		});

		return v;
	}

}
