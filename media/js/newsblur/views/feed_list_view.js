NEWSBLUR.Views.FeedList = Backbone.View.extend({
    
    tagName: 'ul',
    
    className: 'folder NB-feedlist',
    
    options: {
        sorting: "alphabetical"
    },
    
    initialize: function() {
        this.$s = NEWSBLUR.reader.$s;
        
        if (!this.$el.length) return;
        if (this.options.feed_chooser) {
            this.$el.addClass('NB-feedchooser');
            this.$el.addClass('unread_view_positive');
            if (this.options.organizer) {                
                this.$el.attr('id', 'NB-organizer-feeds');
            } else {
                this.$el.attr('id', 'NB-feedchooser-feeds');
            }
            return;
        }
        
        $('.NB-callout-ftux .NB-callout-text').text('Loading feeds...');
        this.$s.$feed_link_loader.css({'display': 'block'});
        NEWSBLUR.assets.feeds.bind('reset', _.bind(function() {
            this.make_feeds();
    
            // TODO: Refactor this to load after both feeds and social feeds load.
            this.load_router();
            this.show_read_stories_header();
            this.update_dashboard_count();
            this.scroll_to_selected();
        }, this));
        NEWSBLUR.assets.social_feeds.bind('reset', _.bind(function() {
            this.make_social_feeds();
        }, this));
        NEWSBLUR.assets.starred_feeds.bind('reset', _.bind(function(models, options) {
            this.make_starred_tags(options);
        }, this));
        NEWSBLUR.assets.social_feeds.bind('change:selected', this.scroll_to_selected, this);
        NEWSBLUR.assets.feeds.bind('change:selected', this.scroll_to_selected, this);
        NEWSBLUR.assets.starred_feeds.bind('change:selected', this.scroll_to_selected, this);
        if (!NEWSBLUR.assets.folders.size()) {
            NEWSBLUR.assets.load_feeds();
        }
        NEWSBLUR.assets.feeds.bind('add', this.update_dashboard_count, this);
        NEWSBLUR.assets.feeds.bind('remove', this.update_dashboard_count, this);
    },
    
    make_feeds: function(options) {
        options = options || {};
        var self = this;
        var folders = options.folders || NEWSBLUR.assets.folders;
        var feeds = NEWSBLUR.assets.feeds;
        
        this.$el.empty();
        this.$s.$story_taskbar.css({'display': 'block'});
        this.folder_view = new NEWSBLUR.Views.Folder({
            collection: folders, 
            root: true,
            hierarchy: this.options.hierarchy,
            feed_chooser: this.options.feed_chooser,
            organizer: this.options.organizer
        }).render();
        this.$el.css({
            'display': 'block', 
            'opacity': 0
        });
        this.$el.addClass("NB-sort-" + this.options.sorting);
        this.$el.html(this.folder_view.el);
        this.$el.animate({'opacity': 1}, {'duration': 700});
        // this.count_collapsed_unread_stories();
        this.$s.$feed_link_loader.fadeOut(250, _.bind(function() {
            this.$s.$feed_link_loader.css({'display': 'none'});
        }, this));
        
        if (!this.options.feed_chooser) {
            if (NEWSBLUR.Globals.is_authenticated && 
                NEWSBLUR.assets.flags['has_chosen_feeds']) {
                _.delay(function() {
                    if (!NEWSBLUR.reader.flags['refresh_inline_feed_delay']) return;
                    NEWSBLUR.reader.start_count_unreads_after_import();
                }, 1000);
                NEWSBLUR.reader.flags['refresh_inline_feed_delay'] = true;
                NEWSBLUR.reader.force_feeds_refresh(function() {
                    NEWSBLUR.reader.flags['refresh_inline_feed_delay'] = false;
                    NEWSBLUR.reader.finish_count_unreads_after_import();
                }, true, null, function() {
                    NEWSBLUR.reader.flags['refresh_inline_feed_delay'] = false;
                    NEWSBLUR.reader.finish_count_unreads_after_import({error: true});
                });
            }

            if (folders.length) {
                $('.NB-task-manage').removeClass('NB-disabled');
                $('.NB-callout-ftux').fadeOut(500);
                // this.load_sortable_feeds();
                _.delay(_.bind(NEWSBLUR.reader.update_starred_count, NEWSBLUR.reader), 250);
                NEWSBLUR.reader.check_hide_getting_started();
                $('.NB-feeds-header-river-sites-container').css({
                    'display': 'block',
                    'opacity': 0
                }).animate({'opacity': 1}, {'duration': 700});
            }
            
            $('.NB-feeds-header-river-global-container').css({
                'display': 'block',
                'opacity': 0
            }).animate({'opacity': 1}, {'duration': 700});

            if (NEWSBLUR.reader.flags['showing_feed_in_tryfeed_view'] ||
                NEWSBLUR.reader.flags['showing_social_feed_in_tryfeed_view']) {
                NEWSBLUR.reader.hide_tryfeed_view();
                NEWSBLUR.reader.force_feed_refresh();
            }
        
            _.defer(_.bind(function() {
                NEWSBLUR.reader.open_dialog_after_feeds_loaded();
                NEWSBLUR.reader.toggle_focus_in_slider();
                this.scroll_to_selected();
                if (NEWSBLUR.reader.socket) {
                    NEWSBLUR.reader.send_socket_active_feeds();
                } else {
                    var force_socket = NEWSBLUR.Globals.is_admin;
                    NEWSBLUR.reader.setup_socket_realtime_unread_counts(force_socket);
                }
            }, this));
        }
        
        return this;
    },
    
    make_social_feeds: function() {
        var $social_feeds = $('.NB-socialfeeds', this.$s.$social_feeds);
        var profile = NEWSBLUR.assets.user_profile;
        var $feeds = NEWSBLUR.assets.social_feeds.map(function(feed) {
            var feed_view = new NEWSBLUR.Views.FeedTitleView({
                model: feed, 
                type: 'feed', 
                depth: 0
            }).render();
            feed.views.push(feed_view);
            return feed_view.el;
        });

        $social_feeds.empty().css({
            'display': 'block', 
            'opacity': 0
        });            
        $social_feeds.html($feeds);
        if (NEWSBLUR.assets.social_feeds.length) {
            $('.NB-feeds-header-river-blurblogs-container').css({
                'display': 'block',
                'opacity': 0
            }).animate({'opacity': 1}, {'duration': 700});
        }

        var collapsed = NEWSBLUR.app.sidebar.check_river_blurblog_collapsed({skip_animation: true});
        $social_feeds.animate({'opacity': 1}, {'duration': collapsed ? 0 : 700});

        // if (this.socket) {
        //     this.send_socket_active_feeds();
        // }
        
        $('.NB-module-stats-count-shared-stories .NB-module-stats-count-number').text(profile.get('shared_stories_count'));
        $('.NB-module-stats-count-followers .NB-module-stats-count-number').text(profile.get('follower_count'));
        $('.NB-module-stats-count-following .NB-module-stats-count-number').text(profile.get('following_count'));
    },
    
    make_starred_tags: function(options) {
        options = options || {};
        var $starred_feeds = $('.NB-starred-feeds', this.$s.$starred_feeds);
        var $feeds = _.compact(NEWSBLUR.assets.starred_feeds.map(function(feed) {
            if (feed.get('tag') == "" || !feed.get('tag')) return;
            var feed_view = new NEWSBLUR.Views.FeedTitleView({
                model: feed, 
                type: 'feed', 
                depth: 0,
                starred_tag: true
            }).render();
            feed.views.push(feed_view);
            return feed_view.el;
        }));

        $starred_feeds.empty().css({
            'display': 'block', 
            'opacity': options.update ? 1 : 0
        });            
        $starred_feeds.html($feeds);
        if (NEWSBLUR.assets.starred_feeds.length) {
            $('.NB-feeds-header-starred-container').css({
                'display': 'block',
                'opacity': 0
            }).animate({'opacity': 1}, {'duration': options.update ? 0 : 700});
        }

        var collapsed = NEWSBLUR.app.sidebar.check_starred_collapsed({skip_animation: true});
        $starred_feeds.animate({'opacity': 1}, {'duration': (collapsed || options.update) ? 0 : 700});
    },
    
    load_router: function() {
        if (!NEWSBLUR.router) {
            NEWSBLUR.router = new NEWSBLUR.Router;
            var route_found = Backbone.history.start({pushState: true});
            var next = this.load_url_next_param(route_found);
            if (!next && !route_found && NEWSBLUR.assets.preference("autoopen_folder")) {
                this.load_default_folder();
            }
        }
    },

    load_url_next_param: function(route_found) {
        var next = $.getQueryString('next') || $.getQueryString('test');
        if (next == 'optout') {
            NEWSBLUR.reader.open_account_modal({'animate_email': true});
        } else if (next == 'goodies') {
            NEWSBLUR.reader.open_goodies_modal();
        } else if (next == 'newsletters') {
            NEWSBLUR.reader.open_newsletters_modal();
        } else if (next == 'friends') {
            NEWSBLUR.reader.open_friends_modal();
        } else if (next == 'account') {
            NEWSBLUR.reader.open_account_modal();
        } else if (next == 'organizer') {
            NEWSBLUR.reader.open_organizer_modal();
        } else if (next == 'chooser') {
            NEWSBLUR.reader.open_feedchooser_modal();
        } else if (next == 'renew') {
            NEWSBLUR.reader.open_feedchooser_modal({'premium_only': true});
        } else if (next == 'password') {
            NEWSBLUR.reader.open_account_modal({'change_password': true});
        }

        var url = $.getQueryString('url') || $.getQueryString('add');
        if (url) {
            NEWSBLUR.reader.open_add_feed_modal({url: url});
        }

        if (!route_found && window.history.replaceState && !$.getQueryString('test')) {
            // In case this needs to be found again: window.location.href = BACKBONE
            window.history.replaceState({}, null, '/');
        }
        
        return next;
    },
    
    load_default_folder: function() {
        var default_folder = NEWSBLUR.assets.preference('default_folder');
        
        if (!default_folder || default_folder == "") {
            NEWSBLUR.reader.open_river_stories();
        } else {
            var folder = NEWSBLUR.assets.get_folder(default_folder);
            if (folder) {
                NEWSBLUR.reader.open_river_stories(folder.folder_view.$el, folder);
            }
        }
    },
    
    update_dashboard_count: function() {
        var feed_count = _.unique(NEWSBLUR.assets.folders.feed_ids_in_folder()).length;
        $(".NB-module-stats-count-number-sites").html(feed_count);
    },
    
    // ===========
    // = Actions =
    // ===========
    
    scroll_to_show_selected_feed: function() {
        var $feed_lists = this.$s.$feed_lists;
        var model = NEWSBLUR.assets.feeds.selected() || 
                    NEWSBLUR.assets.social_feeds.selected() ||
                    NEWSBLUR.assets.starred_feeds.selected();
        if (!model) return;
        var feed_view = model.get("selected_title_view");
        if (!feed_view) {
            feed_view = _.detect(model.views, _.bind(function(view) {
                return !!view.$el.closest(this.$s.$feed_lists).length;
            }, this));
        }
        if (!feed_view) return;
        
        if (!$feed_lists.isScrollVisible(feed_view.$el)) {
            var scroll = feed_view.$el.position().top;
            var container = $feed_lists.scrollTop();
            var height = $feed_lists.outerHeight();
            $feed_lists.scrollTop(scroll+container-height/5);
        }
        
        return true;
    },
    
    scroll_to_show_highlighted_feed: function() {
        var $feed_lists = this.$s.$feed_lists;
        var $feed = $('.NB-feed-selector-selected');
        
        if (!$feed.length) return;
        
        var is_feed_visible = $feed_lists.isScrollVisible($feed);

        if (!is_feed_visible) {
            var scroll = $feed.position().top;
            var container = $feed_lists.scrollTop();
            var height = $feed_lists.outerHeight();
            $feed_lists.scrollTop(scroll+container-height/5);
        }        
    },
    
    scroll_to_show_selected_folder: function() {
        var $feed_lists = this.$s.$feed_lists;
        var $selected_view;
        
        var folder = NEWSBLUR.assets.folders.selected();
        if (folder) {
            $selected_view = folder.folder_view.$el;
            $selected_view = $selected_view.find('.folder_title').eq(0);
        }
        
        if (!$selected_view && NEWSBLUR.reader.active_feed == 'river:') {
            $selected_view = NEWSBLUR.reader.$s.$river_sites_header.closest(".NB-feeds-header-container");
        } else if (!$selected_view && NEWSBLUR.reader.active_feed == 'starred') {
            $selected_view = NEWSBLUR.reader.$s.$starred_header.closest(".NB-feeds-header-container");
        } else if (!$selected_view && NEWSBLUR.reader.active_feed == 'read') {
            $selected_view = NEWSBLUR.reader.$s.$read_header.closest(".NB-feeds-header-container");
        }
        if (!$selected_view) return;
        
        var is_folder_visible = $feed_lists.isScrollVisible($selected_view);

        if (!is_folder_visible) {
            var scroll = $selected_view.position().top;
            var container = $feed_lists.scrollTop();
            var height = $feed_lists.outerHeight();
            $feed_lists.scrollTop(scroll+container-height/5);
        }
        
        return true;
    },
    
    scroll_to_selected: function() {
        var found = this.scroll_to_show_selected_feed();
        if (!found) {
            this.scroll_to_show_selected_folder();
        }
    },
    
    start_sorting: function() {
        this.options.sorting = true;
    },
    
    end_sorting: function() {
        this.options.sorting = false;
    },
    
    is_sorting: function() {
        return this.options.sorting;
    },
    
    show_read_stories_header: function() {
        NEWSBLUR.reader.$s.$read_header.closest('.NB-feeds-header-read-container')
                                       .addClass('NB-block');
    }
        
});