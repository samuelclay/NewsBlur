package com.newsblur.fragment;

import android.os.Bundle;
import android.support.v4.view.ViewPager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import butterknife.ButterKnife;
import butterknife.Bind;

import com.newsblur.R;
import com.newsblur.activity.Reading;

/*
 * A fragment to hold the story pager.  Eventually this fragment should hold much of the UI and logic
 * currently implemented in the Reading activity.  The crucial part, though, is that the pager exists
 * in a wrapper fragment and that the pager is passed a *child* FragmentManager of this fragment and
 * not just the standard support FM from the activity/context.  The pager platform code appears to
 * expect this design.
 */
public class ReadingPagerFragment extends NbFragment {

    @Bind(R.id.reading_pager) ViewPager pager;

	public static ReadingPagerFragment newInstance() {
		ReadingPagerFragment fragment = new ReadingPagerFragment();
		Bundle arguments = new Bundle();
		fragment.setArguments(arguments);
		return fragment;
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_readingpager, null);
        ButterKnife.bind(this, v);

        Reading activity = ((Reading) getActivity());

		pager.addOnPageChangeListener(activity);
        activity.offerPager(pager, getChildFragmentManager());
		return v;
	}


}
