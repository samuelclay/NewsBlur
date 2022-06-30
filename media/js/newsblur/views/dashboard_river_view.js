NEWSBLUR.Views.DashboardRiver = Backbone.View.extend({
    
    events: {
        "click .NB-module-search-add-url"   : "add_url",
        "click .NB-feedbar-options" : "open_options_popover",
        "click .NB-module-river-favicon" : "reload",
        "click .NB-module-river-title": "open_river",
        "click .NB-dashboard-column-option": "choose_columns"
    },
    
    initialize: function () {
        var $river_on_dashboard = $(".NB-dashboard-rivers-" + this.model.get('river_side') + " .NB-dashboard-river-order-" + this.model.get('river_order'));
        // console.log(['Initialize dashboard river', this.model, this.$el, this.el, $river_on_dashboard])
        // if ($river_on_dashboard.length) {
        //     this.setElement($river_on_dashboard);
        // }
        
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
        this.model.unbind('change:river_id');
        this.model.bind('change:river_id', _.bind(this.initialize, this));
        this.model.unbind("change:columns");
        this.model.bind("change:columns", _.bind(this.on_column_change, this));

        this.render();

        return this;
    },

    render: function () {
        var $river = $(_.template('<div class="NB-module NB-module-river NB-dashboard-river NB-dashboard-river-order-<%= river_order %>">\
            <h5 class="NB-module-header">\
                <div class="NB-dashboard-column-control <% if (parseInt(river_order, 10) == 0 && river_side == "left") { %>NB-active<% } %>">\
                    <ul class="segmented-control NB-dashboard-columns-control">\
                        <li class="NB-dashboard-column-option NB-dashboard-columns-control-1">\
                            <img src="/media/img/icons/nouns/columns-one.svg" class="NB-icon">\
                        </li>\
                        <li class="NB-dashboard-column-option NB-dashboard-columns-control-2">\
                            <img src="/media/img/icons/nouns/columns-two.svg" class="NB-icon">\
                        </li>\
                        <li class="NB-dashboard-column-option NB-dashboard-columns-control-3">\
                            <img src="/media/img/icons/nouns/columns-three.svg" class="NB-icon">\
                        </li>\
                    </ul>\
                </div>\
                <div class="NB-module-river-settings NB-javascript"></div>\
                <div class="NB-module-river-title">\
                    <div class="NB-module-river-favicon"><img src="<%= favicon_url %>"></div>\
                    <div class="NB-module-river-title-text"><%= river_title %></div>\
                </div>\
            </h5>\
            \
            <div class="NB-view-river">\
                <div class="NB-module-item <% if (single_column) { %>NB-story-pane-south<% } else { %>NB-story-pane-west<% } %>">\
                    <div class="NB-story-titles"></div>\
                </div>\
            </div>\
        </div>\
        ', {
            favicon_url: this.model.favicon_url(),
            river_title: NEWSBLUR.reader.feed_title(this.model.get('river_id')),
            river_order: this.model.get('river_order'),
            river_side: this.model.get('river_side'),
            single_column: NEWSBLUR.assets.preference('dashboard_columns') == 1
        }));

        this.$el.html($river);
        this.render_columns();

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
        this.setup_dashboard_refresh();
        this.load_stories();
        this.options_template();
        
        return this;
    },

    render_columns: function () {
        var columns = NEWSBLUR.assets.preference('dashboard_columns');
        
        this.$(".NB-dashboard-columns-control-1").toggleClass('NB-active', columns == 1);
        this.$(".NB-dashboard-columns-control-2").toggleClass('NB-active', columns == 2);
        this.$(".NB-dashboard-columns-control-3").toggleClass('NB-active', columns == 3);

        NEWSBLUR.reader.add_body_classes();

        this.$(".NB-module-item").toggleClass("NB-story-pane-south", columns == 1);
        this.$(".NB-module-item").toggleClass("NB-story-pane-west", columns != 1);
    },

    options_template: function () {
        var $options = $(_.template('<div class="NB-feedbar-options-container">\
            <span class="NB-feedbar-options" role="button">\
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
    
    feeds: function (include_read) {
        var river_id = this.model.get('river_id');

        if (_.string.startsWith(river_id, 'feed:')) {
            return [parseInt(river_id.replace('feed:', ''), 10)];
        }
        if (_.string.startsWith(river_id, 'social:')) {
            return [river_id];
        }
        if (_.string.startsWith(river_id, 'search:feed')) {
            var feed = NEWSBLUR.assets.get_feed(river_id);
            return [feed.get('feed_id').replace('feed:', '')];
        }
        if (_.string.startsWith(river_id, 'search:river')) {
            river_id = river_id.substring("search:".length, river_id.lastIndexOf(":"));
        }
        
        var active_folder = NEWSBLUR.assets.get_folder(river_id);
        if (!active_folder) {
            active_folder = NEWSBLUR.assets.folders;
        }

        var feeds;
        var visible_only = NEWSBLUR.assets.view_setting(river_id, 'read_filter') == 'unread';
        if (visible_only && !include_read) {
            feeds = _.pluck(active_folder.feeds_with_unreads(), 'id');
        }
        if (!feeds || !feeds.length) {
            feeds = active_folder.feed_ids_in_folder();
        }
        // console.log(['River feeds', river_id, feeds.length, feeds]);
        return feeds;
    },

    open_river: function () {
        this.open_story();
    },
    
    // ===========
    // = Refresh =
    // ===========
    
    setup_dashboard_refresh: function() {
        if (NEWSBLUR.Globals.debug) return;
        
        // Reload dashboard graphs every N minutes.
        var reload_interval = NEWSBLUR.Globals.is_staff ? 15*60*1000 : 15*60*1000;
        // var reload_interval = 60*60*1000;
        // console.log(['setup_dashboard_refresh', this.refresh_interval]);
        
        clearTimeout(this.refresh_interval);
        this.refresh_interval = setTimeout(_.bind(function () {
                
            if (NEWSBLUR.reader.flags['deactivate_refresh_dashboard']) {
                console.log(['...NOT refreshing dashboard', this.model.get('river_id')]);
                return;
            }

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
    
    redraw: function () {
        this.story_titles.render({immediate: true});
    },

    reload: function () {
        this.load_stories();
    },

    choose_columns: function ($event) {
        var single_column = $($event.currentTarget).hasClass('NB-dashboard-columns-control-1');
        var double_column = $($event.currentTarget).hasClass('NB-dashboard-columns-control-2');
        var triple_column = $($event.currentTarget).hasClass('NB-dashboard-columns-control-3');
        var columns = single_column ? 1 : double_column ? 2 : triple_column ? 3 : null;

        NEWSBLUR.assets.preference('dashboard_columns', columns);
        NEWSBLUR.app.dashboard_rivers.left.rivers.forEach(function (river) {
            console.log('Set river columns', river, columns);
            river.model.set('columns', columns);
        });
    },

    on_column_change: function () {
        this.render_columns();
        this.redraw();
    },

    load_stories: function (options) {
        if (_.string.startsWith(this.model.get('river_id'), 'search:')) {
            var feed = NEWSBLUR.assets.get_feed(this.model.get('river_id'));
            this.options.query = feed.get('query');
        }

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
        
        // console.log(['dashboard river load_stories', this.model.get('river_id'), this.page, feeds, options, this.$stories.length]);
        this.page = 1;
        this.story_titles.show_loading();
        NEWSBLUR.assets.fetch_dashboard_stories(this.model.get('river_id'), feeds, this.page, this.options.dashboard_stories, options,
            _.bind(this.post_load_stories, this), NEWSBLUR.app.taskbar_info.show_stories_error);
            
        this.setup_dashboard_refresh();
    },
    
    post_load_stories: function (data) {
        // console.log(['post_load_stories', this.model.get('river_id'), this.options.dashboard_stories.length, data, data.stories.length])
        this.story_titles.end_loading();
        this.fill_out({ new_stories: data.stories.length });
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
        var dashboard_count = parseInt(NEWSBLUR.assets.view_setting(this.model.get('river_id'), 'dashboard_count'), 10);
        // console.log(['dashboard_count', this.model.get('river_id'), visible, dashboard_count, options.new_stories == 0]);
        if (visible >= dashboard_count) {
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
            if (this.page > 60) {
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
        
        if (options.new_stories == 0) {
            this.complete_fill();
            return;
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
    
    open_story: function (story) {
        var river_id = this.model.get('river_id');
        var options = {
            dashboard_transfer: this.options.dashboard_stories,
            story_id: story && story.id
        };
        console.log(['Opening dashboard story', story, this.options]);

        if (this.options.query) {
            console.log('Saved search', NEWSBLUR.assets.searches_feeds.get(river_id))
            NEWSBLUR.reader.flags.searching = true;
            NEWSBLUR.reader.flags.search = this.options.query;
            NEWSBLUR.reader.open_saved_search(_.extend({
                search_model: NEWSBLUR.assets.searches_feeds.get(river_id),
                feed_id: river_id,
                query: this.options.query
            }, options));
        } else if (river_id == "river:infrequent") {
            NEWSBLUR.reader.open_river_stories(null, null, _.extend({
                infrequent: this.options.infrequent
            }, options));    
        } else if (river_id == "river:global") {
            NEWSBLUR.reader.open_river_blurblogs_stories(_.extend({
                global: true
            }, options));
        } else if (_.string.startsWith(river_id, 'river:')) {
            var folder = NEWSBLUR.assets.get_folder(river_id.replace('river:', ''));
            if (folder) {
                NEWSBLUR.reader.open_river_stories(folder.folder_view.$el, folder, options);
            } else {
                NEWSBLUR.reader.open_river_stories(null, null, options);
            }
        } else if (river_id == "river:read") {
            NEWSBLUR.reader.open_read_stories(options);
        } else if (_.string.startsWith(river_id, "social:")) {
            NEWSBLUR.reader.open_social_stories(river_id, options);
        } else if (_.string.startsWith(river_id, 'feed:')) {
            NEWSBLUR.reader.open_feed(river_id, options);
        }
    },
    
    show_end_line: function() {
        this.story_titles.show_no_more_stories();
        this.$(".NB-end-line").addClass("NB-visible");
    },
    
    complete_fill: function () {
        // console.log(['complete_fill', this.model.get('river_id')])
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
        } else if (this.options.global_feed) {
            // Global Shared Stories don't come in real-time (yet)
            return;
        } else if (!_.contains(this.feeds(true), parseInt(feed_id, 10))) {
            console.log(['New story not in folder', this.model.get('river_id'), feed_id, this.feeds()]);
            return;
        }
        
        var dashboard_count = parseInt(NEWSBLUR.assets.view_setting(this.model.get('river_id'), 'dashboard_count'), 10);
        var subs = feed.get('num_subscribers');
        var delay = subs * 2; // 1,000 subs = 2 seconds
        // console.log(['Fetching dashboard story', this.model.get('river_id'), story_hash, delay + 'ms delay', dashboard_count]);
        
        if (NEWSBLUR.reader.flags['deactivate_new_dashboard_story']) {
            console.log(['...NOT Fetching dashboard story', this.model.get('river_id')]);
            return;
        }

        // _.delay(_.bind(function() {
        NEWSBLUR.assets.add_dashboard_story(story_hash, this.options.dashboard_stories, dashboard_count);
        // }, this), Math.random() * delay);
        
    },

    open_options_popover: function(e) {
        NEWSBLUR.FeedOptionsPopover.create({
            anchor: this.$(".NB-feedbar-options"),
            feed_id: this.model.get('river_id'),
            river_side: this.model.get('river_side'),
            river_order: this.model.get('river_order'),
            on_dashboard: this,
            show_markscroll: false
        });
    },
    
});
