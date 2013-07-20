package com.newsblur.database;

import java.util.List;

import com.newsblur.domain.Story;

public interface StoryItemsAdapter {

    Story getStory(int position);

    List<Story> getPreviousStories(int position);

}
