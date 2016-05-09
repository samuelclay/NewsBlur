package com.newsblur.fragment;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.app.Fragment;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AbsListView;
import android.widget.AdapterView;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.FeedItemsList;
import com.newsblur.activity.Profile;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.UserDetails;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.ActivityDetails.Category;
import com.newsblur.network.APIManager;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;
import com.newsblur.view.ActivityDetailsAdapter;
import com.newsblur.view.ProgressThrobber;

public abstract class ProfileActivityDetailsFragment extends Fragment implements AdapterView.OnItemClickListener {

    private ListView activityList;
    private ActivityDetailsAdapter adapter;
    protected APIManager apiManager;
    private UserDetails user;
    private ProgressThrobber footerProgressView;
    private ProgressThrobber loadingProgressView;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        apiManager = new APIManager(getActivity());
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        final View v = inflater.inflate(R.layout.fragment_profileactivity, null);
        activityList = (ListView) v.findViewById(R.id.profile_details_activitylist);

        loadingProgressView = (ProgressThrobber) v.findViewById(R.id.empty_view_loading_throb);
        loadingProgressView.setColors(UIUtils.getColor(getActivity(), R.color.refresh_1),
                                      UIUtils.getColor(getActivity(), R.color.refresh_2),
                                      UIUtils.getColor(getActivity(), R.color.refresh_3),
                                      UIUtils.getColor(getActivity(), R.color.refresh_4));
        activityList.setFooterDividersEnabled(false);
        activityList.setEmptyView(v.findViewById(R.id.empty_view));

        View footerView = inflater.inflate(R.layout.row_loading_throbber, null);
        footerProgressView = (ProgressThrobber) footerView.findViewById(R.id.itemlist_loading_throb);
        footerProgressView.setColors(UIUtils.getColor(getActivity(), R.color.refresh_1),
                                     UIUtils.getColor(getActivity(), R.color.refresh_2),
                                     UIUtils.getColor(getActivity(), R.color.refresh_3),
                                     UIUtils.getColor(getActivity(), R.color.refresh_4));
        activityList.addFooterView(footerView, null, false);

        if (adapter != null) {
            displayActivities();
        }
        activityList.setOnScrollListener(new EndlessScrollListener());
        activityList.setOnItemClickListener(this);
        return v;
    }

    public void setUser(Context context, UserDetails user) {
        this.user = user;
        adapter = createAdapter(context, user);
        displayActivities();
    }

    protected abstract ActivityDetailsAdapter createAdapter(Context context, UserDetails user);

    private void displayActivities() {
        activityList.setAdapter(adapter);
        loadPage(1);
    }

    private void loadPage(final int pageNumber) {
        new AsyncTask<Void, Void, ActivityDetails[]>() {

            @Override
            protected void onPreExecute() {
                loadingProgressView.setVisibility(View.VISIBLE);
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
                return loadActivityDetails(id, pageNumber);
            }

            @Override
            protected void onPostExecute(ActivityDetails[] result) {
                if (pageNumber == 1 && result.length == 0) {
                    View emptyView = activityList.getEmptyView();
                    TextView textView = (TextView) emptyView.findViewById(R.id.empty_view_text);
                    textView.setText(R.string.profile_no_interactions);
                }
                for (ActivityDetails activity : result) {
                    adapter.add(activity);
                }
                adapter.notifyDataSetChanged();
                loadingProgressView.setVisibility(View.GONE);
                footerProgressView.setVisibility(View.GONE);
            }
        }.execute();
    }

    protected abstract ActivityDetails[] loadActivityDetails(String id, int pageNumber);

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
                context.startActivity(intent);
            }
        } else if (activity.category == Category.STAR) {
            UIUtils.startReadingActivity(FeedSet.allSaved(), activity.storyHash, context);
        } else if (isSocialFeedCategory(activity)) {
            // Strip the social: prefix from feedId
            String socialFeedId = activity.feedId.substring(7);
            SocialFeed feed = FeedUtils.getSocialFeed(socialFeedId);
            if (feed == null) {
                Toast.makeText(context, R.string.profile_do_not_follow, Toast.LENGTH_SHORT).show();
            } else {
                UIUtils.startReadingActivity(FeedSet.singleSocialFeed(feed.userId, feed.username), activity.storyHash, context);
            }
        }
    }

    private boolean isSocialFeedCategory(ActivityDetails activity) {
        return activity.storyHash != null && (activity.category == Category.COMMENT_LIKE ||
                                              activity.category == Category.COMMENT_REPLY ||
                                              activity.category == Category.REPLY_REPLY ||
                                              activity.category == Category.SHARED_STORY);
    }

    /**
     * Detects when user is close to the end of the current page and starts loading the next page
     * so the user will not have to wait (that much) for the next entries.
     *
     * @author Ognyan Bankov
     *         <p/>
     *         https://github.com/ogrebgr/android_volley_examples/blob/master/src/com/github/volley_examples/Act_NetworkListView.java
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
