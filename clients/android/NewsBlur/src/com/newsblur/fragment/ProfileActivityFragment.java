package com.newsblur.fragment;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.FeedItemsList;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Profile;
import com.newsblur.activity.Reading;
import com.newsblur.activity.SavedStoriesReading;
import com.newsblur.activity.SocialFeedReading;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.ActivityDetails.Category;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.view.ActivityDetailsAdapter;
import com.newsblur.view.ProgressThrobber;

public class ProfileActivityFragment extends Fragment implements AdapterView.OnItemClickListener {

	private ListView activityList;
	private ActivityDetailsAdapter adapter;
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
		adapter = new ActivityDetailsAdapter(context, user);
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
        Context context = getActivity();
        if (activity.category == Category.FOLLOW) {
            Intent i = new Intent(context, Profile.class);
            i.putExtra(Profile.USER_ID, activity.withUserId);
            context.startActivity(i);
        } else if (activity.category == Category.FEED_SUBSCRIPTION) {
            Feed feed = FeedUtils.getFeed(activity.feedId);
            if (feed == null) {
                Toast.makeText(context, R.string.profile_feed_not_available, Toast.LENGTH_SHORT).show();
            } else {
                Intent intent = new Intent(context, FeedItemsList.class);
                intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
                intent.putExtra(ItemsList.EXTRA_STATE, PrefsUtils.getStateFilter(context));
                context.startActivity(intent);
            }
        } else if (activity.category == Category.STAR) {
            Intent i = new Intent(context, SavedStoriesReading.class);
            i.putExtra(Reading.EXTRA_FEEDSET, FeedSet.allSaved());
            i.putExtra(Reading.EXTRA_STORY_HASH, activity.storyHash);
            i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, PrefsUtils.getDefaultFeedViewForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME));
            context.startActivity(i);
        } else if (activity.category == Category.SHARED_STORY) {
            Intent i = new Intent(context, SocialFeedReading.class);
            i.putExtra(Reading.EXTRA_FEEDSET, FeedSet.singleSocialFeed(user.id, user.username));
            i.putExtra(Reading.EXTRA_SOCIAL_FEED, FeedUtils.getSocialFeed(user.id));
            i.putExtra(ItemsList.EXTRA_STATE, PrefsUtils.getStateFilter(context));
            i.putExtra(Reading.EXTRA_STORY_HASH, activity.storyHash);
            i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, PrefsUtils.getDefaultFeedViewForFeed(context, user.id));
            context.startActivity(i);
        } else if ((activity.category == Category.COMMENT_LIKE || activity.category == Category.COMMENT_REPLY) && activity.storyHash != null) {
            // TODO navigate to comment
            SocialFeed feed = FeedUtils.getSocialFeed(activity.withUserId);
            if (feed == null) {
                Toast.makeText(context, R.string.profile_feed_not_available, Toast.LENGTH_SHORT).show();
            } else {
                Intent i = new Intent(context, SocialFeedReading.class);
                i.putExtra(Reading.EXTRA_FEEDSET, FeedSet.singleSocialFeed(activity.withUserId, activity.user.username));
                i.putExtra(Reading.EXTRA_SOCIAL_FEED, feed);
                i.putExtra(ItemsList.EXTRA_STATE, PrefsUtils.getStateFilter(context));
                i.putExtra(Reading.EXTRA_STORY_HASH, activity.storyHash);
                i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, PrefsUtils.getDefaultFeedViewForFeed(context, activity.withUserId));
                context.startActivity(i);
            }
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
