NEWSBLUR.Views.FeedList = Backbone.View.extend({
    
    options: {
        sorting: false
    },
    
    initialize: function() {
        _.bindAll(this, 'selected');
        this.$s = NEWSBLUR.reader.$s;
        
        if (!$('#feed_list').length) return;
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
        NEWSBLUR.assets.load_feeds();
        
        NEWSBLUR.assets.feeds.bind('change:selected', this.selected);
    },
    
    make_feeds: function() {
        var self = this;
        var $feed_list = this.$s.$feed_list;
        var folders = NEWSBLUR.assets.folders;
        var feeds = NEWSBLUR.assets.feeds;
        
        $feed_list.empty();
        this.$s.$story_taskbar.css({'display': 'block'});
        var $feeds = new NEWSBLUR.Views.Folder({collection: folders, root: true}).render().el;
        $feed_list.css({
            'display': 'block', 
            'opacity': 0
        });
        $feed_list.html($feeds);
        $feed_list.animate({'opacity': 1}, {'duration': 700});
        // this.count_collapsed_unread_stories();
        this.$s.$feed_link_loader.fadeOut(250);

        if (NEWSBLUR.Globals.is_authenticated && NEWSBLUR.assets.flags['has_chosen_feeds']) {
            _.delay(function() {
                NEWSBLUR.reader.start_count_unreads_after_import();
            }, 1000);
            NEWSBLUR.reader.flags['refresh_inline_feed_delay'] = true;
            NEWSBLUR.reader.force_feeds_refresh(function() {
                NEWSBLUR.reader.finish_count_unreads_after_import();
            }, true);
        }
        
        if (folders.length) {
            $('.NB-task-manage').removeClass('NB-disabled');
            $('.NB-callout-ftux').fadeOut(500);
            // this.load_sortable_feeds();
            _.delay(_.bind(NEWSBLUR.reader.update_starred_count, NEWSBLUR.reader), 250);
            NEWSBLUR.reader.check_hide_getting_started();
        }
        
        if (NEWSBLUR.reader.flags['showing_feed_in_tryfeed_view'] || NEWSBLUR.reader.flags['showing_social_feed_in_tryfeed_view']) {
            NEWSBLUR.reader.hide_tryfeed_view();
            NEWSBLUR.reader.force_feed_refresh();
        }
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
    },
    
    make_social_feeds: function() {
        var $social_feeds = this.$s.$social_feeds;
        var profile = NEWSBLUR.assets.user_profile;
        var $feeds = NEWSBLUR.assets.social_feeds.map(function(feed) {
            var feed_view = new NEWSBLUR.Views.Feed({model: feed, type: 'feed', depth: 0}).render();
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
            model = NEWSBLUR.assets.feeds.selected();
            console.log(["selected models", model]);
        }
        if (!model) return;
        
        if (options.$feed) {
            feed_view = _.detect(model.views, function(view) {
                return view.el == options.$feed[0];
            });
        }
        if (!feed_view) {
            feed_view = model.views[0];
        }
        
        this.scroll_to_show_selected_feed(feed_view);
    },
    
    scroll_to_show_selected_feed: function(feed_view) {
        var $feed_lists = this.$s.$feed_lists;
        var is_feed_visible = $feed_lists.isScrollVisible(feed_view.$el);
        console.log(["scroll_to_show_selected_feed", feed_view, feed_view.$el, is_feed_visible]);
        if (!is_feed_visible) {
            var container_offset = $feed_lists.position().top;
            var scroll = feed_view.$el.position().top;
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