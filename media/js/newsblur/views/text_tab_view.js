NEWSBLUR.Views.TextTabView = Backbone.View.extend({
    
    initialize: function() {
        this.setElement(NEWSBLUR.reader.$s.$text_view);
        this.collection.bind('change:selected', this.select_story, this);
        this.$story = this.$('.NB-text-view-detail');
    },
    
    // ===========
    // = Actions =
    // ===========
    
    load_story: function(story, is_temporary) {
        if (!story) story = NEWSBLUR.reader.active_story;
        if (!story) return;
        
        if (this.story == story) return;
        
        this.story = story;
        this.$story.html(new NEWSBLUR.Views.StoryDetailView({
            model: this.story,
            show_feed_title: true,
            skip_content: true,
            text_view: true
        }).render().el);
        
        if (is_temporary) {
            NEWSBLUR.reader.switch_taskbar_view('text', {
                skip_save_type: is_temporary ? 'text' : false
            });
        }
        
        this.show_loading();
        NEWSBLUR.assets.fetch_original_text(story.get('id'), story.get('story_feed_id'), 
                                            _.bind(this.render, this), 
                                            _.bind(this.error, this));
    },
    
    render: function(data) {
        if (data.story_id != this.story.get('id') || 
            data.feed_id != this.story.get('story_feed_id')) {
            return;
        }
        
        var original_text = data.original_text;
        this.hide_loading();
        var $content = this.$('.NB-feed-story-content');
        if (original_text.length < (this.story.get('story_content').length / 3)) {
            this.error();
        } else {
            $content.html(original_text);
            NEWSBLUR.reader.make_story_titles_pane_counter();
        }
        $content.css('opacity', 0);
        $content.show();
        $content.animate({
            'opacity': 1
        }, {
            duration: 250,
            queue: false
        });
    },
    
    unload: function() {
        var $content = this.$('.NB-text-view-detail');
        $content.empty();
    },
    
    show_loading: function() {
        NEWSBLUR.reader.hide_stories_error();
        NEWSBLUR.reader.show_stories_progress_bar(10, "Fetching text");
    },
    
    hide_loading: function() {
        NEWSBLUR.reader.hide_stories_progress_bar();
    },
    
    error: function() {
        this.hide_loading();
        NEWSBLUR.reader.show_stories_error({}, "Sorry, the story\'s text<br />could not be extracted.");
        
        var $content = this.$('.NB-feed-story-content');
        $content.html(this.story.get('story_content'));
    },
    
    // ==========
    // = Events =
    // ==========
    
    select_story: function(story, selected) {
        if (selected && NEWSBLUR.reader.story_view == 'text') {
            if (NEWSBLUR.reader.flags['temporary_story_view']) {
                NEWSBLUR.reader.switch_to_correct_view();
            }
            this.load_story(story);
        }
    }
    
});