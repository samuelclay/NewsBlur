package com.newsblur.fragment;

import java.util.ArrayList;
import java.util.List;

import android.view.ContextMenu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.View.OnCreateContextMenuListener;
import android.widget.AdapterView;

import com.newsblur.R;
import com.newsblur.database.StoryItemsAdapter;
import com.newsblur.domain.Story;
import com.newsblur.util.FeedUtils;

public abstract class StoryItemListFragment extends ItemListFragment implements OnCreateContextMenuListener {

    @Override
    public void onCreateContextMenu(ContextMenu menu, View v,
            ContextMenuInfo menuInfo) {
        MenuInflater inflater = getActivity().getMenuInflater();
        
        inflater.inflate(R.menu.context_story, menu);
    }
    
    @Override
    public boolean onContextItemSelected(MenuItem item) {
        final AdapterView.AdapterContextMenuInfo menuInfo = (AdapterView.AdapterContextMenuInfo)item.getMenuInfo();
        if (item.getItemId() == R.id.menu_mark_story_as_read) {
            final Story story = adapter.getStory(menuInfo.position);
            if(! story.read) {
                List<Story> storiesToMarkAsRead = new ArrayList<Story>();
                storiesToMarkAsRead.add(story);
                FeedUtils.markStoriesAsRead(storiesToMarkAsRead, getActivity());
                hasUpdated();
            }
        } else if (item.getItemId() == R.id.menu_mark_previous_stories_as_read) {
            final List<Story> previousStories = adapter.getPreviousStories(menuInfo.position);
            List<Story> storiesToMarkAsRead = new ArrayList<Story>();
            for(Story story: previousStories) {
                if(! story.read) {
                    storiesToMarkAsRead.add(story);
                }
            }
            FeedUtils.markStoriesAsRead(storiesToMarkAsRead, getActivity());
            hasUpdated();
        } else if (item.getItemId() == R.id.menu_shared) {
            Story story = adapter.getStory(menuInfo.position);
            FeedUtils.shareStory(story, getActivity());
        }
        return super.onContextItemSelected(item);
    }

}
