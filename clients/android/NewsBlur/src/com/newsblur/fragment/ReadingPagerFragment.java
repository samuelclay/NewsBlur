package com.newsblur.fragment;

import android.database.Cursor;
import android.graphics.Typeface;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.Parcelable;
import android.support.v4.app.Fragment;
import android.support.v4.app.LoaderManager;
import android.support.v4.content.Loader;
import android.support.v4.view.ViewPager;
import android.support.v7.widget.GridLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.GestureDetector;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewTreeObserver.OnGlobalLayoutListener;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.activity.Reading;
import com.newsblur.activity.NbActivity;
import com.newsblur.database.StoryViewAdapter;
import com.newsblur.domain.Story;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryListStyle;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;
import com.newsblur.view.ProgressThrobber;

public class ReadingPagerFragment extends NbFragment {

    @Bind(R.id.reading_pager) ViewPager pager;

	public static ReadingPagerFragment newInstance() {
		ReadingPagerFragment fragment = new ReadingPagerFragment();
		Bundle arguments = new Bundle();
		fragment.setArguments(arguments);
		return fragment;
	}

    @Override
    public void onCreate(Bundle savedInstanceState) {
            com.newsblur.util.Log.d(this, "DD - onCreate");
        super.onCreate(savedInstanceState);
    }
    
    @Override
    public void onStart() {
        super.onStart();
    }

    @Override
    public void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
    }

    @Override
    public void onPause() {
        super.onPause();
    }

    @Override
    public void onResume() {
        super.onResume();
    }

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
            com.newsblur.util.Log.d(this, "DD - onCreateView");
		View v = inflater.inflate(R.layout.fragment_readingpager, null);
        ButterKnife.bind(this, v);

        Reading activity = ((Reading) getActivity());

		pager.addOnPageChangeListener(activity);
        activity.offerPager(pager, getChildFragmentManager());
		return v;
	}


}
