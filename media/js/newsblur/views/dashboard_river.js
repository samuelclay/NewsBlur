NEWSBLUR.Views.DashboardRiver = Backbone.View.extend({
    
    el: ".NB-module-river",
    
    events: {
        "click .NB-module-search-add-url"        : "add_url"
    },
    
    initialize: function() {
        this.active_feed = 'river:';
        this.active_folder = NEWSBLUR.assets.folders;
        this.$stories = this.$(".NB-module-item .NB-story-titles");
        this.story_titles = new NEWSBLUR.Views.StoryTitlesView({
            el: this.$stories,
            collection: NEWSBLUR.assets.dashboard_stories,
            $story_titles: this.$stories,
            override_layout: 'split',
            on_dashboard: true
        });
        this.page = 1;
        
        NEWSBLUR.assets.feeds.bind('reset', _.bind(this.load_stories, this));
    },
    
    feeds: function() {
        var feeds;
        var visible_only = NEWSBLUR.assets.view_setting(this.active_feed, 'read_filter') == 'unread';
        if (visible_only) {
            feeds = _.pluck(this.active_folder.feeds_with_unreads(), 'id');
            if (!feeds.length) {
                feeds = this.active_folder.feed_ids_in_folder();
            }
        } else {
            feeds = this.active_folder.feed_ids_in_folder();
        }
        
        return feeds;
    },
    
    // ==========
    // = Events =
    // ==========
    
    load_stories: function() {
        // var feeds = NEWSBLUR.assets.folders.feed_ids_in_folder();
        var feeds = this.feeds();
        
        this.page = 1;
        this.story_titles.show_loading();
        NEWSBLUR.assets.fetch_dashboard_stories("river:", feeds, this.page, 
            _.bind(this.post_load_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error);
    },
    
    post_load_stories: function() {
        this.fill_out();
    },
    
    fill_out: function() {
        var visible = NEWSBLUR.assets.dashboard_stories.visible().length;
        if (visible >= 3 && !NEWSBLUR.Globals.is_premium) {
            this.story_titles.check_premium_river();
            return;
        }
        if (visible >= 5 || this.page > 10) return;
        
        var feeds = this.feeds();
        this.page += 1;
        this.story_titles.show_loading();
        NEWSBLUR.assets.fetch_dashboard_stories("river:", feeds, this.page, 
            _.bind(this.post_load_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error);        
    }
    
});