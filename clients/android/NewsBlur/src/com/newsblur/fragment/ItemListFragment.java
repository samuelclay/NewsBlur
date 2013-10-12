package com.newsblur.fragment;

import com.newsblur.util.StoryOrder;

import android.support.v4.app.Fragment;

public abstract class ItemListFragment extends Fragment {
	
	public abstract void hasUpdated();
	public abstract void changeState(final int state);
	public abstract void setStoryOrder(StoryOrder storyOrder);

}
