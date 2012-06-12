NEWSBLUR.Views.StoryTabView = Backbone.View.extend({
    
    initialize: function() {
        this.setElement(NEWSBLUR.reader.$s.$story_iframe);
        this.collection.bind('change:selected', this.select_story, this);
    },
    
    // ===========
    // = Actions =
    // ===========
    
    open_story: function(story, is_temporary) {
        if (!story) story = NEWSBLUR.reader.active_story;
        var feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));

        if ((feed && feed.get('disabled_page')) || 
            NEWSBLUR.utils.is_url_iframe_buster(story.get('story_permalink'))) {
            if (!is_temporary) {
                NEWSBLUR.reader.switch_taskbar_view('feed', 'story');
            }
        } else {
            NEWSBLUR.reader.switch_taskbar_view('story', is_temporary ? 'story' : false);
            this.load_story_iframe(story);
        }
    },
    
    load_story_iframe: function(story) {
        story = story || NEWSBLUR.reader.active_story;
        if (!story) return;
        
        if (this.$el.attr('src') != story.get('story_permalink')) {
            this.unload_story_iframe();
        
            NEWSBLUR.reader.flags.iframe_scroll_snap_back_prepared = true;
            this.$el.removeAttr('src').attr({src: story.get('story_permalink')});
        }
    },
    
    unload_story_iframe: function() {
        this.$el.empty();
        this.$el.removeAttr('src').attr({src: 'about:blank'});
    },
    
    // ==========
    // = Events =
    // ==========
    
    select_story: function(story, selected) {
        if (selected && NEWSBLUR.reader.story_view == 'story') {
            this.open_story(story);
        }
    }
    
});