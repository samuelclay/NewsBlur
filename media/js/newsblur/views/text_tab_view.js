NEWSBLUR.Views.TextTabView = Backbone.View.extend({
    
    events: {
        "click .NB-premium-only a" : function(e) {
            e.preventDefault();
            NEWSBLUR.reader.open_feedchooser_modal();
        }
    },
    
    initialize: function() {
        _.bindAll(this, 'render', 'error');
        
        if (this.collection) {
            this.collection.bind('change:selected', this.select_story, this);
        }
    },
    
    destroy: function() {
        this.remove();
    },
    
    // ===========
    // = Actions =
    // ===========
    
    fetch_and_render: function(story, is_temporary) {
        if (!story) story = NEWSBLUR.reader.active_story;
        if (!story && is_temporary) {
            NEWSBLUR.reader.show_next_story(1);
            story = NEWSBLUR.reader.active_story;
        }
        if (!story) return;

        if (is_temporary) {
            NEWSBLUR.reader.switch_taskbar_view('text', {
                skip_save_type: is_temporary ? 'text' : false
            });
        }

        if (this.story == story) return;
        
        this.story = story;
        this.$el.html(new NEWSBLUR.Views.StoryDetailView({
            model: this.story,
            show_feed_title: true,
            skip_content: true,
            text_view: true,
            tagName: 'div'
        }).render().el);
        this.$el.scrollTop(0);
        this.show_loading();
        NEWSBLUR.assets.fetch_original_text(story.get('id'), story.get('story_feed_id'), 
                                            this.render, this.error);
                                            
        return this;
    },
    
    render: function(data) {
        if (data && (data.story_id != this.story.get('id') || 
                     data.feed_id != this.story.get('story_feed_id'))) {
            return;
        }
        
        this.hide_loading();
        var $content = this.$('.NB-feed-story-content');

        if (!this.story.get('original_text') || 
            this.story.get('original_text').length < (this.story.get('story_content').length / 3)) {
            this.error();
        } else {
            $content.html(this.story.get('original_text'));
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
        
        if (!NEWSBLUR.Globals.is_premium) {
            this.append_premium_only_notification();
        }
    },
    
    unload: function() {
        this.story = null;
        this.$el.empty();
    },
    
    show_loading: function() {
        NEWSBLUR.app.taskbar_info.hide_stories_error();
        NEWSBLUR.app.taskbar_info.show_stories_progress_bar(10, "Fetching text");
    },
    
    hide_loading: function() {
        NEWSBLUR.app.taskbar_info.hide_stories_progress_bar();
    },
    
    error: function() {
        this.hide_loading();
        NEWSBLUR.app.taskbar_info.show_stories_error({}, "Sorry, the story\'s text<br />could not be extracted.");
        
        var $content = this.$('.NB-feed-story-content');
        $content.html(this.story.get('story_content'));
    },
    
    append_premium_only_notification: function() {
        var $content = this.$('.NB-feed-story-content');
        var $notice = $.make('div', { className: 'NB-text-view-premium-only' }, [
            $.make('div', { className: 'NB-feed-story-premium-only-divider'}),
            $.make('div', { className: 'NB-feed-story-premium-only-text'}, [
                'The full ',
                $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/silk/application_view_columns.png' }),
                ' Text view is a ',
                $.make('a', { href: '#', className: 'NB-splash-link' }, 'premium feature'),
                '.'
            ])
        ]);
        
        $notice.hide();
        this.$('.NB-feed-story-premium-only').remove();
        $content.after($notice);
        this.$el.addClass('NB-premium-only');
        
        $notice.css('opacity', 0);
        $notice.show();
        $notice.animate({'opacity': 1}, {'duration': 250, 'queue': false});
    },
    
    // ==========
    // = Events =
    // ==========
    
    select_story: function(story, selected) {
        if (selected && NEWSBLUR.reader.story_view == 'text' &&
            NEWSBLUR.assets.preference('story_layout') == 'split') {
            if (NEWSBLUR.reader.flags['temporary_story_view']) {
                NEWSBLUR.reader.switch_to_correct_view();
            }
            this.fetch_and_render(story);
        }
    }
    
});