package com.newsblur.activity;

import java.util.List;

import com.newsblur.R;
import com.newsblur.domain.FeedResult;
import com.newsblur.util.UIUtils;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.text.TextUtils;
import android.util.Base64;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.TextView;

public class FeedSearchResultAdapter extends ArrayAdapter<FeedResult>{

	private LayoutInflater inflater;
	private Context context;

	public FeedSearchResultAdapter(Context context, int resource, int textViewResourceId, List<FeedResult> items) {
		super(context, resource, textViewResourceId, items);
		this.context = context;
		inflater = ((Activity) context).getLayoutInflater();
	}
	
	@Override
	public View getView(int position, View convertView, ViewGroup parent) {
		View v;
		if (convertView != null) {
			v = convertView;
		} else {
			v = inflater.inflate(R.layout.row_feedresult, null);
		}
		
		FeedResult result = getItem(position);
		ImageView favicon = (ImageView) v.findViewById(R.id.row_result_feedicon);
		Bitmap bitmap = null;
		if (!TextUtils.isEmpty(result.favicon)) {
			final byte[] data = Base64.decode(result.favicon, Base64.DEFAULT);
			bitmap = BitmapFactory.decodeByteArray(data, 0, data.length);
		}
		if (bitmap == null) {
			bitmap = BitmapFactory.decodeResource(context.getResources(), R.drawable.world);
		}
		
		favicon.setImageBitmap(UIUtils.roundCorners(bitmap, 5));
		
		((TextView) v.findViewById(R.id.row_result_title)).setText(result.label);
		((TextView) v.findViewById(R.id.row_result_tagline)).setText(result.tagline);
		
		return v;
	}

}
