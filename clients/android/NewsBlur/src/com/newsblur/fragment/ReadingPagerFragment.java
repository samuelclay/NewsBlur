package com.newsblur.fragment;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.newsblur.R;
import com.newsblur.activity.Reading;
import com.newsblur.databinding.FragmentReadingpagerBinding;

/*
 * A fragment to hold the story pager.  Eventually this fragment should hold much of the UI and logic
 * currently implemented in the Reading activity.  The crucial part, though, is that the pager exists
 * in a wrapper fragment and that the pager is passed a *child* FragmentManager of this fragment and
 * not just the standard support FM from the activity/context.  The pager platform code appears to
 * expect this design.
 */
public class ReadingPagerFragment extends NbFragment {

	public static ReadingPagerFragment newInstance() {
		ReadingPagerFragment fragment = new ReadingPagerFragment();
		Bundle arguments = new Bundle();
		fragment.setArguments(arguments);
		return fragment;
	}

	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
		View v = inflater.inflate(R.layout.fragment_readingpager, null);
		FragmentReadingpagerBinding binding = FragmentReadingpagerBinding.bind(v);

        Reading activity = ((Reading) getActivity());

		binding.readingPager.addOnPageChangeListener(activity);
        activity.offerPager(binding.readingPager, getChildFragmentManager());
		return v;
	}


}
