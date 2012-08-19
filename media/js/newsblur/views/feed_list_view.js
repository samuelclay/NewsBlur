NEWSBLUR.Views.FeedList = Backbone.View.extend({
    
    tagName: 'ul',
    
    className: 'folder NB-feedlist',
    
    options: {
        sorting: false
    },
    
    initialize: function() {
        this.$s = NEWSBLUR.reader.$s;
        
        if (!this.$el.length) return;
        if (this.options.feed_chooser) {
            this.$el.addClass('NB-feedchooser');
            this.$el.addClass('unread_view_positive');
            this.$el.attr('id', 'NB-feedchooser-feeds');
            return;
        }
        
        $('.NB-callout-ftux .NB-callout-text').text('Loading feeds...');
        this.$s.$feed_link_loader.css({'display': 'block'});
        NEWSBLUR.assets.feeds.bind('reset', _.bind(function() {
            this.make_feeds();
    
            // TODO: Refactor this to load after both feeds and social feeds load.
            this.load_router();
        }, this));
        NEWSBLUR.assets.social_feeds.bind('reset', _.bind(function() {
            this.make_social_feeds();
        }, this));
        NEWSBLUR.assets.social_feeds.bind('change:selected', this.selected, this);
        NEWSBLUR.assets.feeds.bind('change:selected', this.selected, this);

        if (!NEWSBLUR.assets.folders.size()) {
            NEWSBLUR.assets.load_feeds();
        }

    },
    
    make_feeds: function(options) {
        options = options || {};
        var self = this;
        var folders = NEWSBLUR.assets.folders;
        var feeds = NEWSBLUR.assets.feeds;
        
        this.$el.empty();
        this.$s.$story_taskbar.css({'display': 'block'});
        var $feeds = new NEWSBLUR.Views.Folder({
            collection: folders, 
            root: true,
            feed_chooser: this.options.feed_chooser
        }).render().el;
        this.$el.css({
            'display': 'block', 
            'opacity': 0
        });
        this.$el.html($feeds);
        this.$el.animate({'opacity': 1}, {'duration': 700});
        // this.count_collapsed_unread_stories();
        this.$s.$feed_link_loader.fadeOut(250);

        if (!this.options.feed_chooser && 
            NEWSBLUR.Globals.is_authenticated && 
            NEWSBLUR.assets.flags['has_chosen_feeds']) {
            _.delay(function() {
                NEWSBLUR.reader.start_count_unreads_after_import();
            }, 1000);
            NEWSBLUR.reader.flags['refresh_inline_feed_delay'] = true;
            NEWSBLUR.reader.force_feeds_refresh(function() {
                NEWSBLUR.reader.finish_count_unreads_after_import();
            }, true);
        }
        
        if (folders.length && !this.options.feed_chooser) {
            $('.NB-task-manage').removeClass('NB-disabled');
            $('.NB-callout-ftux').fadeOut(500);
            // this.load_sortable_feeds();
            _.delay(_.bind(NEWSBLUR.reader.update_starred_count, NEWSBLUR.reader), 250);
            NEWSBLUR.reader.check_hide_getting_started();
        }
        
        if (!this.options.feed_chooser &&
            (NEWSBLUR.reader.flags['showing_feed_in_tryfeed_view'] ||
             NEWSBLUR.reader.flags['showing_social_feed_in_tryfeed_view'])) {
            NEWSBLUR.reader.hide_tryfeed_view();
            NEWSBLUR.reader.force_feed_refresh();
        }
        
        if (!this.options.feed_chooser) {
            _.defer(_.bind(function() {
                NEWSBLUR.reader.open_dialog_after_feeds_loaded();
                this.selected();
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
        var $social_feeds = this.$s.$social_feeds;
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
        $social_feeds.animate({'opacity': 1}, {'duration': 700});

        // if (this.socket) {
        //     this.send_socket_active_feeds();
        // }
        
        $('.NB-module-stats-count-shared-stories .NB-module-stats-count-number').text(profile.get('shared_stories_count'));
        $('.NB-module-stats-count-followers .NB-module-stats-count-number').text(profile.get('follower_count'));
        $('.NB-module-stats-count-following .NB-module-stats-count-number').text(profile.get('following_count'));
    },
    
    load_router: function() {
        if (!NEWSBLUR.router) {
            NEWSBLUR.router = new NEWSBLUR.Router;
            var route_found = Backbone.history.start({pushState: true});
            this.load_url_next_param(route_found);
        }
    },

    load_url_next_param: function(route_found) {
        var next = $.getQueryString('next');
        if (next == 'optout') {
            NEWSBLUR.reader.open_account_modal({'animate_email': true});
        } else if (next == 'goodies') {
            NEWSBLUR.reader.open_goodies_modal();
        } else if (next == 'friends') {
            NEWSBLUR.reader.open_friends_modal();
        } else if (next == 'chooser') {
            NEWSBLUR.reader.open_feedchooser_modal();
        } else if (next == 'password') {
            NEWSBLUR.reader.open_account_modal({'change_password': true});
        }

        var url = $.getQueryString('url');
        if (url) {
            NEWSBLUR.reader.open_add_feed_modal({url: url});
        }

        if (!route_found && window.history.replaceState) {
            // In case this needs to be found again: window.location.href = BACKBONE
            window.history.replaceState({}, null, '/');
        }
    },
    
    // ===========
    // = Actions =
    // ===========
    
    selected: function(model, value, options) {
        var feed_view;
        options = options || {};
        
        if (!model) {
            model = NEWSBLUR.assets.feeds.selected() || NEWSBLUR.assets.social_feeds.selected();
        }
        if (!model || !model.get('selected')) return;
        
        if (options.$feed) {
            feed_view = _.detect(model.views, function(view) {
                return view.el == options.$feed[0];
            });
        }
        if (!feed_view) {
            feed_view = _.detect(model.views, _.bind(function(view) {
                return !!view.$el.closest(this.$s.$feed_lists).length;
            }, this));
        }
        
        if (feed_view) {
            this.scroll_to_show_selected_feed(feed_view);
        }
    },
    
    scroll_to_show_selected_feed: function(feed_view) {
        var $feed_lists = this.$s.$feed_lists;
        
        if (!feed_view) {
            var model = NEWSBLUR.assets.feeds.selected() || NEWSBLUR.assets.social_feeds.selected();
            if (!model || !model.get('selected')) return;
            var feed_view = _.detect(model.views, _.bind(function(view) {
                return !!view.$el.closest(this.$s.$feed_lists).length;
            }, this));
            if (!feed_view) return;
        }
        var is_feed_visible = $feed_lists.isScrollVisible(feed_view.$el);
        // NEWSBLUR.log(["scroll_to_show_selected_feed", feed_view, feed_view.$el, is_feed_visible]);

        if (!is_feed_visible) {
            var scroll = feed_view.$el.position().top;
            var container = $feed_lists.scrollTop();
            var height = $feed_lists.outerHeight();
            $feed_lists.scrollTop(scroll+container-height/5);
        }        
    },
    
    scroll_to_show_selected_folder: function(folder_view) {
        var $feed_lists = this.$s.$feed_lists;
        
        if (!folder_view) {
            var folder = NEWSBLUR.assets.folders.selected();
            if (!folder || !folder.get('selected')) return;
            folder_view = folder.folder_view;
            if (!folder_view) return;
        }

        var $folder_title = folder_view.$el.find('.folder_title').eq(0);
        var is_folder_visible = $feed_lists.isScrollVisible($folder_title);
        // NEWSBLUR.log(["scroll_to_show_selected_folder", folder_view, folder_view.$el, $feed_lists, is_folder_visible]);

        if (!is_folder_visible) {
            var scroll = folder_view.$el.position().top;
            var container = $feed_lists.scrollTop();
            var height = $feed_lists.outerHeight();
            $feed_lists.scrollTop(scroll+container-height/5);
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
    }
    
});