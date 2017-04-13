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
        this.cache = {
            story_hashes: []
        };
        
        NEWSBLUR.assets.feeds.bind('reset', _.bind(this.load_stories, this));
        NEWSBLUR.assets.stories.bind('change:read_status', this.check_read_stories, this);
        // NEWSBLUR.assets.stories.bind('change:selected', this.check_read_stories, this);
        
        this.setup_dashboard_refresh();
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
    
    // ===========
    // = Refresh =
    // ===========
    
    setup_dashboard_refresh: function() {
        // if (NEWSBLUR.Globals.debug) return;
        
        // Reload dashboard graphs every N minutes.
        // var reload_interval = NEWSBLUR.Globals.is_staff ? 60*1000 : 10*60*1000;
        var reload_interval = 60*60*1000;
        // console.log(['setup_dashboard_refresh', this.refresh_interval]);
        
        clearTimeout(this.refresh_interval);
        this.refresh_interval = setTimeout(_.bind(function() {
            if (NEWSBLUR.reader.active_feed == this.active_feed) {
                // Currently reading the river, so don't reload because it'll break the cache.
                console.log(['Currently reading river, so not reloading dashboard river', NEWSBLUR.reader.active_feed]);
                this.setup_dashboard_refresh();
            } else {
                this.load_stories();
            }
        }, this), reload_interval * (Math.random() * (1.25 - 0.75) + 0.75));
    },
    
    // ==========
    // = Events =
    // ==========
    
    load_stories: function(options) {
        options = options || {};
        // console.log(['dashboard river load_stories', this.page, options]);
        if (options.feed_selector) return;
        // var feeds = NEWSBLUR.assets.folders.feed_ids_in_folder();
        var feeds = this.feeds();
        if (!feeds.length) return;
        if (!this.$stories.length) return;
        
        this.page = 1;
        this.story_titles.show_loading();
        NEWSBLUR.assets.fetch_dashboard_stories(this.active_feed, feeds, this.page, 
            _.bind(this.post_load_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error);
            
        this.setup_dashboard_refresh();
    },
    
    post_load_stories: function() {
        this.fill_out();
        this.cache.story_hashes = NEWSBLUR.assets.dashboard_stories.pluck('story_hash');
    },
    
    fill_out: function() {
        var visible = NEWSBLUR.assets.dashboard_stories.visible().length;
        if (visible >= 3 && !NEWSBLUR.Globals.is_premium) {
            this.story_titles.check_premium_river();
            this.complete_fill();
            return;
        }
        if (visible >= 5) {
            this.complete_fill();
            return;
        }
        
        var counts = NEWSBLUR.assets.folders.unread_counts();
        var unread_view = NEWSBLUR.assets.preference('unread_view');
        if (unread_view >= 1) {
            // console.log(['counts', counts['ps'], visible, this.page]);
            if (counts['ps'] <= visible) {
                this.show_end_line();
                return;
            }
            if (this.page > 20) {
                this.complete_fill();
                return;
            }
        } else {
            if (counts['nt'] <= visible) {
                this.show_end_line();
                return;
            }
            if (this.page > 20) {
                this.complete_fill();
                return;
            }
        }
        
        var feeds = this.feeds();
        this.page += 1;
        this.story_titles.show_loading();
        NEWSBLUR.assets.fetch_dashboard_stories(this.active_feed, feeds, this.page, 
            _.bind(this.post_load_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error);        
    },
    
    check_read_stories: function(story, attr) {
        // console.log(['story read', story, story.get('story_hash'), story.get('read_status'), attr]);
        if (!_.contains(this.cache.story_hashes, story.get('story_hash'))) return;
        var dashboard_story = NEWSBLUR.assets.dashboard_stories.get_by_story_hash(story.get('story_hash'));
        if (!dashboard_story) {
            console.log(['Error: missing story on dashboard', story, this.cache.story_hashes]);
            return;
        }
        
        dashboard_story.set('read_status', story.get('read_status'));
        // dashboard_story.set('selected', false);
    },
    
    open_story: function(story) {
        NEWSBLUR.reader.open_river_stories(null, null, {
            dashboard_transfer: true,
            story_id: story.id
        });
    },
    
    show_end_line: function() {
        this.story_titles.show_no_more_stories();
        this.$(".NB-end-line").addClass("NB-visible");
    },
    
    complete_fill: function() {
        var feeds = this.feeds();
        NEWSBLUR.assets.complete_river(this.active_feed, feeds, this.page);
    },
    
    new_story: function(story_hash, timestamp) {
        var current_timestamp = Math.floor(Date.now() / 1000);
        if (timestamp > (current_timestamp + 60*60)) {
            console.log(['New story newer than current time + 1 hour', 
                         (timestamp - current_timestamp)/60 + " minutes newer"]);
            return;
        }
        
        var oldest_story = NEWSBLUR.assets.dashboard_stories.last();
        if (oldest_story) {
            var last_timestamp = parseInt(oldest_story.get('story_timestamp'), 10);
            timestamp = parseInt(timestamp, 10);
            
            if (NEWSBLUR.assets.view_setting(this.active_feed, 'order') == 'newest') {
                if (timestamp < last_timestamp) {
                    // console.log(['New story older than last/oldest dashboard story', timestamp, '<', last_timestamp]);
                    return;
                }
            } else {
                if (timestamp > last_timestamp) {
                    // console.log(['New story older than last/newest dashboard story', timestamp, '<', last_timestamp]);
                    return;
                }
            }
        }
        
        var feed_id = story_hash.split(':')[0];
        var feed = NEWSBLUR.assets.get_feed(feed_id);
        if (!feed) {
            console.log(["Can't fetch dashboard story, no feed", feed_id]);
            return;
        }
        var subs = feed.get('num_subscribers');
        var delay = subs * 2; // 1,000 subs = 2 seconds
        console.log(['Fetching dashboard story', story_hash, delay + 'ms delay']);
        
        _.delay(function() {
            NEWSBLUR.assets.add_dashboard_story(story_hash);
        }, Math.random() * delay);
        
    }
    
});