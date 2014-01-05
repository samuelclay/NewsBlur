package com.newsblur.fragment;

import android.support.v4.app.Fragment;
import android.util.Log;
import android.view.View;
import android.widget.ListView;
import android.widget.TextView;

import com.newsblur.R;
import com.newsblur.util.StoryOrder;

public abstract class ItemListFragment extends Fragment {
	
	public abstract void hasUpdated();
	public abstract void changeState(final int state);
	public abstract void setStoryOrder(StoryOrder storyOrder);

    public void setEmptyListView(int rid) {
        View v = this.getView();
        if (v == null) return; // we might have beat construction?

        ListView itemList = (ListView) v.findViewById(R.id.itemlistfragment_list);
        if (itemList == null) {
            Log.w(this.getClass().getName(), "ItemListFragment does not have the expected ListView.");
            return;
        }

        TextView emptyView = (TextView) itemList.getEmptyView();
        emptyView.setText(rid);
    }
    
}
