package com.newsblur.network;

import java.lang.ref.WeakReference;

import android.os.AsyncTask;
import android.widget.ImageView;

public class MarkCommentAsFavouriteTask extends AsyncTask<Void, Void, Void> {

	WeakReference<ImageView> referenceToView;
	private String commentId;
	
	public MarkCommentAsFavouriteTask(ImageView favouriteIconView, final String commentId) {
		this.commentId = commentId;
		referenceToView = new WeakReference<ImageView>(favouriteIconView);
	}
	
	
	@Override
	protected Void doInBackground(Void... params) {
		// TODO Auto-generated method stub
		return null;
	}
	
	

}
