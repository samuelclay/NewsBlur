package com.newsblur.service;

import com.newsblur.network.APIClient;

import android.app.IntentService;
import android.content.Intent;
import android.os.Bundle;
import android.os.ResultReceiver;
import android.util.Log;

/**
 * The SyncService is based on an app architecture that tries to place network calls
 * (especially larger calls or those called regularly) on independent services, making the 
 * activity / fragment a passive receiver of its updates. This, along with data fragments for  
 * handling UI updates, prevent network bottlenecks and ensure the UI is passively updated
 * and decoupled from network calls. Examples of other apps using this architecture include 
 * the NBCSportsTalk and Google I/O 2011 apps.
 */
public class SyncService extends IntentService {

	private static final String TAG = "SyncService";
	public static final String EXTRA_STATUS_RECEIVER = "resultReceiverExtra";
	public final int STATUS_RUNNING = 0;
	public final int STATUS_FINISHED = 1;
	public final int STATUS_ERROR = 2;
	public APIClient apiClient;
	
	public SyncService() {
		super(TAG);
	}

	@Override
	public void onCreate() {
		apiClient = new APIClient(this);
	}
	
	@Override
	protected void onHandleIntent(Intent intent) {
		Log.d(TAG, "Received SyncService handleIntent call.");
		final ResultReceiver receiver = intent.getParcelableExtra(EXTRA_STATUS_RECEIVER);
		try {
			// TODO: Synchronise feedshere.
		} catch (Exception e) {
			Log.e(TAG, "Couldn't synchronise with Newsblur servers.", e.getCause());
		}
		
		if (receiver != null) {
			receiver.send(STATUS_FINISHED, Bundle.EMPTY);
		}
	}

}
