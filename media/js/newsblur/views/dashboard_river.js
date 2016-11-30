NEWSBLUR.Views.DashboardRiver = Backbone.View.extend({
    
    el: ".NB-module-river",
    
    events: {
        "click .NB-module-search-add-url"        : "add_url"
    },
    
    initialize: function() {
        this.$stories = this.$(".NB-module-item");
        this.story_titles = new NEWSBLUR.Views.StoryTitlesView({
            collection: NEWSBLUR.assets.dashboard_stories,
            $story_titles: this.$stories
        });
        // this.$stories.html(this.story_titles.$el);
        
        NEWSBLUR.assets.feeds.bind('reset', _.bind(this.load_stories, this));
    },
    
    // ==========
    // = Events =
    // ==========
    
    load_stories: function() {
        var feeds = NEWSBLUR.assets.folders.feed_ids_in_folder();
        this.story_titles.show_loading();
        NEWSBLUR.assets.fetch_dashboard_stories("river:", feeds, 1, 
            _.bind(this.post_load_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error);
    },
    
    post_load_stories: function() {
        console.log(['$story_title', this.story_titles.el, this.$stories[0], NEWSBLUR.reader.$s.$story_titles[0]]);
    }
    
});