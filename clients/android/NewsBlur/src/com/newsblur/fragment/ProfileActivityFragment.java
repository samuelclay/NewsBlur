package com.newsblur.fragment;

import android.content.Context;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.view.ActivitiesAdapter;

public class ProfileActivityFragment extends Fragment {

	private ListView activityList;
	private ActivitiesAdapter adapter;
	private APIManager apiManager;
	private UserDetails user;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		apiManager = new APIManager(getActivity());
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		final View v = inflater.inflate(R.layout.fragment_profileactivity, null);
		activityList = (ListView) v.findViewById(R.id.profile_details_activitylist);
		if (adapter != null) {
			displayActivities();
		}
		activityList.setOnScrollListener(new EndlessScrollListener());
		return v;
	}
	
	public void setUser(Context context, UserDetails user) {
		// TODO reset the page number in the listener for new user?
		this.user = user;
		adapter = new ActivitiesAdapter(context, user);
		displayActivities();
	}
	
	private void displayActivities() {
		activityList.setAdapter(adapter);
		loadPage(1);
	}

	private void loadPage(final int pageNumber) {
		// TODO progress indicator
		// TODO pass limit?
		new AsyncTask<Void, Void, ActivityDetails[]>() {

			@Override
			protected ActivityDetails[] doInBackground(Void... voids) {
				ActivitiesResponse activitiesResponse = apiManager.getActivities(user.id, pageNumber);
				if (activitiesResponse != null) {
					return activitiesResponse.activities;
				} else {
					return new ActivityDetails[0];
				}
			}

			@Override
			protected void onPostExecute(ActivityDetails[] result) {
				for (ActivityDetails activity : result) {
					adapter.add(activity);
				}
				adapter.notifyDataSetChanged();
			}
		}.execute();
	}

	/**
	 * Detects when user is close to the end of the current page and starts loading the next page
	 * so the user will not have to wait (that much) for the next entries.
	 *
	 * @author Ognyan Bankov
	 *
	 * https://github.com/ogrebgr/android_volley_examples/blob/master/src/com/github/volley_examples/Act_NetworkListView.java
	 */
	public class EndlessScrollListener implements AbsListView.OnScrollListener {
		// how many entries earlier to start loading next page
		private int visibleThreshold = 5;
		private int currentPage = 1;
		private int previousTotal = 0;
		private boolean loading = true;

		public EndlessScrollListener() {
		}
		public EndlessScrollListener(int visibleThreshold) {
			this.visibleThreshold = visibleThreshold;
		}

		@Override
		public void onScroll(AbsListView view, int firstVisibleItem,
							 int visibleItemCount, int totalItemCount) {
			if (loading) {
				if (totalItemCount > previousTotal) {
					loading = false;
					previousTotal = totalItemCount;
					currentPage++;
				}
			}
			if (!loading && (totalItemCount - visibleItemCount) <= (firstVisibleItem + visibleThreshold)) {
				// I load the next page of gigs using a background task,
				// but you can call any function here.
				loadPage(currentPage);
				loading = true;
			}
		}

		@Override
		public void onScrollStateChanged(AbsListView view, int scrollState) {

		}
	}
}
