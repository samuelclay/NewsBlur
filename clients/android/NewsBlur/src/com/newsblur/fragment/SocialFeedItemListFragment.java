package com.newsblur.fragment;

import android.content.CursorLoader;
import android.content.Intent;
import android.content.Loader;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;

import com.newsblur.R;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Reading;
import com.newsblur.activity.SocialFeedReading;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MultipleFeedItemsAdapter;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.view.SocialItemViewBinder;

public class SocialFeedItemListFragment extends ItemListFragment implements OnItemClickListener {

	private SocialFeed socialFeed;
	private ListView itemList;

    @Override
	public void onCreate(Bundle savedInstanceState) {
        socialFeed = (SocialFeed) getArguments().getSerializable("social_feed");
		super.onCreate(savedInstanceState);
		getLoaderManager().initLoader(ITEMLIST_LOADER , null, this);
	}

	public static SocialFeedItemListFragment newInstance(SocialFeed socialFeed, StateFilter currentState, DefaultFeedView defaultFeedView) {
	    SocialFeedItemListFragment fragment = new SocialFeedItemListFragment();
		Bundle args = new Bundle();
        args.putSerializable("currentState", currentState);
        args.putSerializable("social_feed", socialFeed);
        args.putSerializable("defaultFeedView", defaultFeedView);
        fragment.setArguments(args);
        return fragment;
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_itemlist, null);
		itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        setupBezelSwipeDetector(itemList);
		itemList.setEmptyView(v.findViewById(R.id.empty_view));
        itemList.setOnScrollListener(this);
		itemList.setOnItemClickListener(this);
        if (adapter != null) {
            itemList.setAdapter(adapter);
        }
		
		return v;
	}

    @Override
	public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        if ((adapter == null) && (cursor != null)) {
            String[] groupFroms = new String[] { DatabaseConstants.STORY_TITLE, DatabaseConstants.FEED_FAVICON_URL, DatabaseConstants.FEED_TITLE, DatabaseConstants.STORY_SHORT_CONTENT, DatabaseConstants.STORY_TIMESTAMP, DatabaseConstants.STORY_AUTHORS, DatabaseConstants.STORY_INTELLIGENCE_AUTHORS};
            int[] groupTos = new int[] { R.id.row_item_title, R.id.row_item_feedicon, R.id.row_item_feedtitle, R.id.row_item_content, R.id.row_item_date, R.id.row_item_author, R.id.row_item_sidebar};
            adapter = new MultipleFeedItemsAdapter(getActivity(), R.layout.row_socialitem, cursor, groupFroms, groupTos);
            adapter.setViewBinder(new SocialItemViewBinder(getActivity()));
            itemList.setAdapter(adapter);
        }
        super.onLoadFinished(loader, cursor);
    }

	@Override
	public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
        if (getActivity().isFinishing()) return;
		Intent i = new Intent(getActivity(), SocialFeedReading.class);
        i.putExtra(Reading.EXTRA_FEEDSET, getFeedSet());
		i.putExtra(Reading.EXTRA_USERID, socialFeed.userId);
		i.putExtra(Reading.EXTRA_USERNAME, socialFeed.username);
		i.putExtra(Reading.EXTRA_POSITION, position);
		i.putExtra(ItemsList.EXTRA_STATE, currentState);
        i.putExtra(Reading.EXTRA_DEFAULT_FEED_VIEW, defaultFeedView);
		startActivity(i);
	}

}
