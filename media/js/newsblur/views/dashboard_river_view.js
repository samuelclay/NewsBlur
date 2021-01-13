NEWSBLUR.Views.DashboardRiver = Backbone.View.extend({
    
    el: ".NB-module-river",
    
    events: {
        "click .NB-module-search-add-url"   : "add_url",
        "click .NB-feedbar-options" : "open_options_popover"
    },
    
    initialize: function () {
        console.log(['Initialize dashboard river', this.model])
        var $river_on_dashboard = $(".NB-dashboard-rivers-" + this.model.get('river_side') + " .NB-dashboard-river-order-" + this.model.get('river_order'));
        this.setElement($river_on_dashboard);
        this.$el.html(this.template());
        
        this.$stories = this.$(".NB-module-item .NB-story-titles");
        
        // console.log(['dashboard stories view', this.$stories, this.options, this.$stories.el]);
        
        this.story_titles = new NEWSBLUR.Views.StoryTitlesView({
            el: this.$stories.get(0),
            collection: this.options.dashboard_stories,
            $story_titles: this.$stories,
            override_layout: 'split',
            on_dashboard: this
        });
        this.page = 1;
        this.cache = {
            story_hashes: []
        };
        
        if (this.model.get('river_id') == "river:infrequent") {
            this.options.infrequent = NEWSBLUR.assets.preference('infrequent_stories_per_month');
        } else if (this.model.get('river_id') == "river:global") {
            this.options.global_feed = true;
        }

        NEWSBLUR.assets.feeds.unbind(null, null, this);
        NEWSBLUR.assets.feeds.bind('reset', _.bind(this.load_stories, this));
        NEWSBLUR.assets.stories.unbind(null, null, this);
        NEWSBLUR.assets.stories.bind('change:read_status', this.check_read_stories, this);
        // NEWSBLUR.assets.stories.bind('change:selected', this.check_read_stories, this);
        this.model.bind('change:feed_id', _.bind(this.initialize, this));
        
        this.setup_dashboard_refresh();
        this.load_stories();
        this.options_template();

        return this;
    },

    template: function () {
        var $river = $(_.template('<div class="NB-module NB-module-river NB-dashboard-river NB-dashboard-river-order-<%= river_order %>">\
            <h5 class="NB-module-header">\
                <div class="NB-module-river-settings NB-javascript"></div>\
                <div class="NB-module-river-title"><%= river_title %></div>\
            </h5>\
            \
            <div class="NB-view-river">\
                <div class="NB-module-item NB-story-pane-west">\
                    <div class="NB-story-titles"></div>\
                </div>\
            </div>\
        </div>\
        ', {
            river_title: NEWSBLUR.reader.feed_title(this.model.get('river_id')),
            river_order: this.model.get('river_order')
        }));

        return $river;
    },

    options_template: function () {
        var $options = $(_.template('<div class="NB-feedbar-options-container">\
            <span class="NB-feedbar-options">\
                <div class="NB-icon"></div>\
                <%= NEWSBLUR.assets.view_setting(feed_id, "read_filter") %>\
                &middot;\
                <%= NEWSBLUR.assets.view_setting(feed_id, "order") %>\
            </span>\
        </div>', {
            feed_id: this.model.get('river_id')
        }));
        
        this.$(".NB-module-river-settings").html($options);
    },
    
    feeds: function() {
        var feeds;
        var visible_only = NEWSBLUR.assets.view_setting(this.model.get('river_id'), 'read_filter') == 'unread';
        if (visible_only) {
            feeds = _.pluck(this.options.active_folder.feeds_with_unreads(), 'id');
            if (!feeds.length) {
                feeds = this.options.active_folder.feed_ids_in_folder();
            }
        } else {
            feeds = this.options.active_folder.feed_ids_in_folder();
        }
        
        return feeds;
    },
    
    // ===========
    // = Refresh =
    // ===========
    
    setup_dashboard_refresh: function() {
        if (NEWSBLUR.Globals.debug) return;
        
        // Reload dashboard graphs every N minutes.
        var reload_interval = NEWSBLUR.Globals.is_staff ? 60*1000 : 15*60*1000;
        // var reload_interval = 60*60*1000;
        // console.log(['setup_dashboard_refresh', this.refresh_interval]);
        
        clearTimeout(this.refresh_interval);
        this.refresh_interval = setTimeout(_.bind(function() {
            if (NEWSBLUR.reader.active_feed == this.model.get('river_id')) {
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
        options = _.extend({
            global_feed: this.options.global_feed,
            infrequent: this.options.infrequent,
            query: this.options.query,
        }, options || {});
        if (options.feed_selector) return;
        
        var feeds = this.feeds();
        if (!feeds.length) return;
        if (!this.$stories.length) return;
        if (this.model.get('river_id') == "river:global") feeds = [];
        
        // console.log(['dashboard river load_stories', this.model.get('river_id'), this.page, feeds.length, options]);
        this.page = 1;
        this.story_titles.show_loading();
        NEWSBLUR.assets.fetch_dashboard_stories(this.model.get('river_id'), feeds, this.page, this.options.dashboard_stories, options,
            _.bind(this.post_load_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error);
            
        this.setup_dashboard_refresh();
    },
    
    post_load_stories: function (stories) {
        // console.log(['post_load_stories', this.model.get('river_id'), this.options.dashboard_stories.length, stories])
        this.fill_out();
        this.cache.story_hashes = this.options.dashboard_stories.pluck('story_hash');
    },
    
    fill_out: function(options) {
        options = _.extend({
            global_feed: this.options.global_feed,
            infrequent: this.options.infrequent,
            query: this.options.query
        }, options || {});

        if (this.options.dashboard_stories.length == 0) {
            this.show_end_line();
            return;
        }

        var visible = this.options.dashboard_stories.visible().length;
        // console.log("Visible", visible, options)
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
        NEWSBLUR.assets.fetch_dashboard_stories(this.model.get('river_id'), feeds, this.page, this.options.dashboard_stories, options,
            _.bind(this.post_load_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error);        
    },
    
    check_read_stories: function(story, attr) {
        // console.log(['story read', story, story.get('story_hash'), story.get('read_status'), attr]);
        if (!_.contains(this.cache.story_hashes, story.get('story_hash'))) return;
        var dashboard_story = this.options.dashboard_stories.get_by_story_hash(story.get('story_hash'));
        if (!dashboard_story) {
            console.log(['Error: missing story on dashboard', story, this.cache.story_hashes]);
            return;
        }
        
        dashboard_story.set('read_status', story.get('read_status'));
        // dashboard_story.set('selected', false);
    },
    
    open_story: function(story) {
        console.log(['Opening dashboard story', story, this.options]);
        if (this.options.query) {
            console.log('Saved search', NEWSBLUR.assets.searches_feeds.get(this.model.get('river_id')))
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = this.options.query;
            NEWSBLUR.reader.open_saved_search({
                search_model: NEWSBLUR.assets.searches_feeds.get(this.model.get('river_id')),
                feed_id: this.model.get('river_id'),
                dashboard_transfer: this.options.dashboard_stories,
                story_id: story.id,
                query: this.options.query
            });
        } else if (this.model.get('river_id') == "river:infrequent") {
            NEWSBLUR.reader.open_river_stories(null, null, {
                dashboard_transfer: this.options.dashboard_stories,
                infrequent: this.options.infrequent,
                story_id: story.id
            });    
        } else if (this.model.get('river_id') == "river:global") {
            NEWSBLUR.reader.open_river_blurblogs_stories({
                global: true,
                dashboard_transfer: this.options.dashboard_stories,
                story_id: story.id
            });
        } else if (_.string.startsWith(this.model.get('river_id'), 'river:')) {
            NEWSBLUR.reader.open_river_stories(null, null, {
                dashboard_transfer: this.options.dashboard_stories,
                story_id: story.id
            });    
        }
    },
    
    show_end_line: function() {
        this.story_titles.show_no_more_stories();
        this.$(".NB-end-line").addClass("NB-visible");
    },
    
    complete_fill: function() {
        var feeds = this.feeds();
        NEWSBLUR.assets.complete_river(this.model.get('river_id'), feeds, this.page);
    },
    
    new_story: function(story_hash, timestamp) {
        var current_timestamp = Math.floor(Date.now() / 1000);
        if (timestamp > (current_timestamp + 60*60)) {
            console.log(['New story newer than current time + 1 hour', 
                         (timestamp - current_timestamp)/60 + " minutes newer"]);
            return;
        }
        
        var oldest_story = this.options.dashboard_stories.last();
        if (oldest_story) {
            var last_timestamp = parseInt(oldest_story.get('story_timestamp'), 10);
            timestamp = parseInt(timestamp, 10);
            
            if (NEWSBLUR.assets.view_setting(this.model.get('river_id'), 'order') == 'newest') {
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

        if (this.options.infrequent) {
            var feed_stories_per_month = feed.get('average_stories_per_month');
            if (feed_stories_per_month > NEWSBLUR.assets.preference('infrequent_stories_per_month')) {
                return;
            }
        }

        if (this.options.global_feed) {
            // Global Shared Stories don't come in real-time (yet)
            return;
        }

        var subs = feed.get('num_subscribers');
        var delay = subs * 2; // 1,000 subs = 2 seconds
        console.log(['Fetching dashboard story', story_hash, delay + 'ms delay']);
        
        _.delay(_.bind(function() {
            NEWSBLUR.assets.add_dashboard_story(story_hash, this.options.dashboard_stories);
        }, this), Math.random() * delay);
        
    },

    open_options_popover: function(e) {
        NEWSBLUR.FeedOptionsPopover.create({
            anchor: this.$(".NB-feedbar-options"),
            feed_id: this.model.get('river_id'),
            on_dashboard: this
        });
    },
    
});
