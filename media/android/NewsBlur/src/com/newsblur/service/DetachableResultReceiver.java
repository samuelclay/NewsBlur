package com.newsblur.service;

import android.os.Bundle;
import android.os.Handler;
import android.os.ResultReceiver;
import android.util.Log;

/**
 * This class is based on the Google I/O 2011 app's class of the same name. It allows for 
 * a resultreceiver to attach/detach to an activity and thus elegantly handle configuration changes. 
 */
public class DetachableResultReceiver extends ResultReceiver {

	private final static String TAG = "DetachableResultReceiver";
	private Receiver receiver;
	
	public DetachableResultReceiver(Handler handler) {
		super(handler);
	}
	
	public void clearReceiver() {
		receiver = null;
	}
	
	public void setReceiver(final Receiver resultReceiver) {
		receiver = resultReceiver;
	}
	
	public interface Receiver {
		public void onReceiverResult(int resultCode, Bundle resultData);
	}
	
	@Override
	protected void onReceiveResult(int resultCode, Bundle resultData) {
		if (receiver != null) {
			Log.d(TAG, "Sending receiver result...");
			receiver.onReceiverResult(resultCode, resultData);
		} else {
			Log.w(TAG, "No receiver to handle result: " + resultCode + " " + resultData.toString());
		}
	}

}
