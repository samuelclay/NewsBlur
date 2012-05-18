NEWSBLUR.Views.FeedList = Backbone.View.extend({
    
    initialize: function() {
        this.$s = NEWSBLUR.reader.$s;
        this.model = NEWSBLUR.assets;
        
        if (!$('#feed_list').length) return;
        $('.NB-callout-ftux .NB-callout-text').text('Loading feeds...');
        this.$s.$feed_link_loader.css({'display': 'block'});
        NEWSBLUR.reader.flags['favicons_downloaded'] = false;
        NEWSBLUR.assets.feeds.bind('reset', _.bind(function() {
            this.make_feeds();
            this.make_social_feeds();
            this.load_router();
        }, this));
        NEWSBLUR.assets.load_feeds();
    },
    
    make_feeds: function() {
        var self = this;
        var $feed_list = this.$s.$feed_list;
        var folders = this.model.folders;
        var feeds = this.model.feeds;
        
        // NEWSBLUR.log(['Making feeds', {'folders': folders, 'feeds': feeds}]);
        $feed_list.empty();
        
        this.$s.$story_taskbar.css({'display': 'block'});
        var $feeds = new NEWSBLUR.Views.Folder(this.model.folders).render().el;
        $feed_list.css({
            'display': 'block', 
            'opacity': 0
        });
        $feed_list.html($feeds);
        $feed_list.animate({'opacity': 1}, {'duration': 700});
        this.count_collapsed_unread_stories();
        this.hover_over_feed_titles($feed_list);
        this.$s.$feed_link_loader.fadeOut(250);

        if (folders.length) {
            $('.NB-task-manage').removeClass('NB-disabled');
            $('.NB-callout-ftux').fadeOut(500);
        }
        this.open_dialog_after_feeds_loaded();
        if (NEWSBLUR.Globals.is_authenticated && this.model.flags['has_chosen_feeds']) {
            _.delay(_.bind(this.start_count_unreads_after_import, this), 1000);
            this.flags['refresh_inline_feed_delay'] = true;
            this.force_feeds_refresh($.rescope(this.finish_count_unreads_after_import, this), true);
        }
        
        if (folders.length) {
            this.load_sortable_feeds();
            this.update_header_counts();
            _.delay(_.bind(this.update_starred_count, this), 250);
            NEWSBLUR.reader.check_hide_getting_started();
        }
        
        if (this.flags['showing_feed_in_tryfeed_view'] || this.flags['showing_social_feed_in_tryfeed_view']) {
            this.hide_tryfeed_view();
            this.force_feed_refresh();
        }
        _.defer(_.bind(function() {
            this.make_feed_favicons();
            // this.model.load_feed_favicons($.rescope(this.make_feed_favicons, this), this.flags['favicons_downloaded'], this.model.flags['has_chosen_feeds']);
            if (this.socket) {
                this.send_socket_active_feeds();
            } else {
                var force_socket = NEWSBLUR.Globals.is_admin;
                this.setup_socket_realtime_unread_counts(force_socket);
            }
        }, this));
    },
    
    make_social_feeds: function() {
        var $social_feeds = this.$s.$social_feeds;
        var profile = this.model.user_profile;
        
        $social_feeds.empty();
        
        var $feeds = "";
        this.model.social_feeds.sort().each(_.bind(function(feed) {
            var $feed = this.make_feed_title_template(feed.attributes, 'feed', 0);
            $feeds += $feed;
        }, this));

        $social_feeds.css({
            'display': 'block', 
            'opacity': 0
        });            
        $social_feeds.html($feeds);
        $social_feeds.animate({'opacity': 1}, {'duration': 700});

        if (this.socket) {
            this.send_socket_active_feeds();
        }
        
        $('.NB-module-stats-count-shared-stories .NB-module-stats-count-number').text(profile.get('shared_stories_count'));
        $('.NB-module-stats-count-followers .NB-module-stats-count-number').text(profile.get('follower_count'));
        $('.NB-module-stats-count-following .NB-module-stats-count-number').text(profile.get('following_count'));
    }
    
});