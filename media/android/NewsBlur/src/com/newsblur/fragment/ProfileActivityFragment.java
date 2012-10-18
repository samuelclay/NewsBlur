package com.newsblur.fragment;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.domain.UserDetails;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.view.ActivitiesAdapter;

public class ProfileActivityFragment extends Fragment {

	private ListView activityList;
	ActivitiesAdapter adapter;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		final View v = inflater.inflate(R.layout.fragment_profileactivity, null);
		activityList = (ListView) v.findViewById(R.id.profile_details_activitylist);
		if (adapter != null) {
			displayActivities();
		}
		return v;
	}
	
	public void setActivitiesAndUser(final ActivitiesResponse[] activities, UserDetails user ) {
		// Set the activities, create the adapter
		adapter = new ActivitiesAdapter(getActivity(), activities, user);
		displayActivities();
	}
	
	private void displayActivities() {
		activityList.setAdapter(adapter);
	}

}
