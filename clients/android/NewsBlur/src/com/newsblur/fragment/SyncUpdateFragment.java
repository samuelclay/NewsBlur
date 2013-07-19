package com.newsblur.fragment;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.Fragment;
import android.util.Log;

import com.newsblur.service.DetachableResultReceiver;
import com.newsblur.service.DetachableResultReceiver.Receiver;
import com.newsblur.service.SyncService;

public class SyncUpdateFragment extends Fragment implements Receiver {

        public static final String TAG = SyncUpdateFragment.class.getName();
		public DetachableResultReceiver receiver;
		public boolean syncRunning = false;

		public SyncUpdateFragment() {
			receiver = new DetachableResultReceiver(new Handler());
			receiver.setReceiver(this);
		}

		@Override
		public void onCreate(Bundle savedInstanceState) {
			super.onCreate(savedInstanceState);
			setRetainInstance(true);
		}

		@Override
		public void onAttach(Activity activity) {
			super.onAttach(activity);
		}

		@Override
		public void onReceiverResult(int resultCode, Bundle resultData) {
            final SyncService.SyncStatus resultStatus = SyncService.SyncStatus.values()[resultCode];
			switch (resultStatus) {
			case STATUS_FINISHED:
				syncRunning = false;
				if (getActivity() != null) {
					((SyncUpdateFragmentInterface) getActivity()).updateAfterSync();
				}
				break;
			case STATUS_PARTIAL_PROGRESS:
				syncRunning = true;
				if (getActivity() != null) {
					((SyncUpdateFragmentInterface) getActivity()).updatePartialSync();
				}
				break;
			case STATUS_FINISHED_CLOSE:
				syncRunning = false;
				if (getActivity() != null) {
					((SyncUpdateFragmentInterface) getActivity()).closeAfterUpdate();
				}
				break;	
			case STATUS_RUNNING:
				syncRunning = true;
				break;
			case STATUS_NO_MORE_UPDATES:
				syncRunning = false;
				if (getActivity() != null) {
					((SyncUpdateFragmentInterface) getActivity()).setNothingMoreToUpdate();
				}
				break;	
			default:
				syncRunning = false;
				Log.e(this.getClass().getName(), "Sync completed with an unknown result.");
				break;
			}
		}
		
		@Override
		public void onActivityCreated(Bundle savedInstanceState) {
			super.onActivityCreated(savedInstanceState);
			((SyncUpdateFragmentInterface) getActivity()).updateSyncStatus(syncRunning);
		}
		

		public interface SyncUpdateFragmentInterface {
			public void updateAfterSync();
            public void updatePartialSync();
			public void closeAfterUpdate();
			public void setNothingMoreToUpdate();
			public void updateSyncStatus(boolean syncRunning);
		}
}

