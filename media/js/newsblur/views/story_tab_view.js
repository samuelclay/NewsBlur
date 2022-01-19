NEWSBLUR.Views.StoryTabView = Backbone.View.extend({
        
    flags: {},
    
    initialize: function() {
        this.setElement(NEWSBLUR.reader.$s.$story_view);
        this.$iframe = NEWSBLUR.reader.$s.$story_iframe;
        this.collection.bind('change:selected', this.select_story, this);
        this.$iframe.on('load', _.bind(function() {
            this.ensure_proxied_story();
        }, this));
    },
    
    // ===========
    // = Actions =
    // ===========
    
    prepare_story: function(story, is_temporary) {
        if (!story) story = NEWSBLUR.reader.active_story;
        if (!story) return;
        var feed = NEWSBLUR.assets.get_feed(story.get('story_feed_id'));

        if ((feed && feed.get('disabled_page')) || 
            NEWSBLUR.utils.is_url_iframe_buster(story.get('story_permalink'))) {
            if (!is_temporary) {
                NEWSBLUR.reader.switch_taskbar_view('text', {skip_save_type: 'story'});
                NEWSBLUR.app.taskbar_info.show_stories_error({}, "Sorry, the original story<br />could not be proxied.");
            }
        } else {
            NEWSBLUR.reader.switch_taskbar_view('story', {skip_save_type: is_temporary ? 'story' : false});
        }
    },
    
    open_story: function(story) {
        if (!story) story = NEWSBLUR.reader.active_story;
        if (!story) return;
        
        var permalink = story.get('story_permalink');
        // if (window.location.protocol == 'https:' && !_.string.startsWith(permalink, 'https')) {
            this.flags.proxied_https = true;
            this.load_original_story_page(story);
        // } else {
        //     this.flags.proxied_https = false;
        //     this.load_story_iframe(story);
        // }
    },
    
    load_original_story_page: function(story) {
        this.$(".NB-story-list-empty").remove();
        this.show_loading();
        var url = '/rss_feeds/original_story?story_hash='+story.get('story_hash');
        console.log(['url', url]);
        if (!_.string.contains(this.$iframe.attr('src'), url)) {
            this.unload_story_iframe();
        
            NEWSBLUR.reader.flags.iframe_scroll_snap_back_prepared = true;
            this.$iframe.removeAttr('src').attr({src: url});
        }
    },
    
    load_story_iframe: function(story) {
        story = story || NEWSBLUR.reader.active_story;
        if (!story) return;
        
        this.$(".NB-story-list-empty").remove();
        if (this.$iframe.attr('src') != story.get('story_permalink')) {
            this.unload_story_iframe();
        
            NEWSBLUR.reader.flags.iframe_scroll_snap_back_prepared = true;
            this.$iframe.removeAttr('src').attr({src: story.get('story_permalink')});
        }
    },
    
    unload_story_iframe: function() {
        NEWSBLUR.app.taskbar_info.hide_stories_error();
        
        this.$iframe.empty();
        this.$iframe.removeAttr('src');//.attr({src: 'about:blank'});
    },
    
    show_explainer_single_story_mode: function() {
        var $empty = $.make("div", { className: "NB-story-list-empty" }, [
            $.make('div', { className: 'NB-world' }),
            'Select a story to read'
        ]);

        this.$(".NB-story-list-empty").remove();
        this.$el.append($empty);
    },

    show_loading: function() {
        NEWSBLUR.app.taskbar_info.hide_stories_error();
        NEWSBLUR.app.taskbar_info.show_stories_progress_bar(10, "Fetching story");
    },
    
    ensure_proxied_story: function() {
        NEWSBLUR.app.taskbar_info.hide_stories_progress_bar();
        if (this.$iframe.attr('src') == 'about:blank') {
            console.log(['Blank iframe, ignoring']);
            NEWSBLUR.app.taskbar_info.hide_stories_error();
            return;
        }
        var correct = this.$iframe.contents().find('body').children().length;
        console.log(['correct?', this.$iframe.contents(), this.$iframe.contents().find('body').children().length]);
        if (correct && this.flags.proxied_https) {
            // NEWSBLUR.app.taskbar_info.show_stories_error({
            //     proxied_https: true
            // }, "Imperfect proxy due<br />to http over https");
        } else if (!correct && this.flags.proxied_https) {
            // NEWSBLUR.reader.switch_taskbar_view('text', {skip_save_type: 'story'});
            // NEWSBLUR.app.taskbar_info.show_stories_error({}, "Sorry, the original story<br />could not be proxied.");
        }
    },

    // ==========
    // = Events =
    // ==========
    
    select_story: function(story, selected) {
        if (selected && NEWSBLUR.reader.story_view == 'story') {
            this.prepare_story(story);
            this.open_story(story);
        }
    }
    
});
