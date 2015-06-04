package com.newsblur.fragment;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.Fragment;
import android.text.TextUtils;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.AdapterView;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.activity.Profile;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.view.ActivitiesAdapter;
import com.newsblur.view.ProgressThrobber;

public class ProfileActivityFragment extends Fragment implements AdapterView.OnItemClickListener {

	private ListView activityList;
	private ActivitiesAdapter adapter;
	private APIManager apiManager;
	private UserDetails user;
    private ProgressThrobber footerProgressView;

    @Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		apiManager = new APIManager(getActivity());
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		final View v = inflater.inflate(R.layout.fragment_profileactivity, null);
		activityList = (ListView) v.findViewById(R.id.profile_details_activitylist);

        View footerView = inflater.inflate(R.layout.row_loading_throbber, null);
        footerProgressView = (ProgressThrobber) footerView.findViewById(R.id.itemlist_loading_throb);
        footerProgressView.setColors(getResources().getColor(R.color.refresh_1),
                                     getResources().getColor(R.color.refresh_2),
                                     getResources().getColor(R.color.refresh_3),
                                     getResources().getColor(R.color.refresh_4));
        activityList.addFooterView(footerView, null, false);
        activityList.setFooterDividersEnabled(false);

		if (adapter != null) {
			displayActivities();
		}
		activityList.setOnScrollListener(new EndlessScrollListener());
        activityList.setOnItemClickListener(this);
		return v;
	}
	
	public void setUser(Context context, UserDetails user) {
		this.user = user;
		adapter = new ActivitiesAdapter(context, user);
		displayActivities();
	}
	
	private void displayActivities() {
		activityList.setAdapter(adapter);
		loadPage(1);
	}

	private void loadPage(final int pageNumber) {
		new AsyncTask<Void, Void, ActivityDetails[]>() {

            @Override
            protected void onPreExecute() {
                footerProgressView.setVisibility(View.VISIBLE);
            }

            @Override
			protected ActivityDetails[] doInBackground(Void... voids) {
				// For the logged in user user.userId is null.
				// From the user intent user.userId is the number while user.id is prefixed with social:
				String id = user.userId;
				if (id == null) {
					id = user.id;
				}
				ActivitiesResponse activitiesResponse = apiManager.getActivities(id, pageNumber);
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
                footerProgressView.setVisibility(View.GONE);
			}
		}.execute();
	}

    @Override
    public void onItemClick(AdapterView<?> adapterView, View view, int position, long id) {
        ActivityDetails activity = adapter.getItem(position);
        if (TextUtils.equals(activity.category, "follow")) {
            Context context = getActivity();
            Intent i = new Intent(context, Profile.class);
            i.putExtra(Profile.USER_ID, activity.id);
            context.startActivity(i);
        }
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
