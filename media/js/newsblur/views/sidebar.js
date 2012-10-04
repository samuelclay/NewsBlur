NEWSBLUR.Views.Sidebar = Backbone.View.extend({
    
    el: '.NB-sidebar',
    
    events: {
        "click .NB-feeds-header-starred": "open_starred_stories",
        "click .NB-feeds-header-river-sites": "open_river_stories",
        "click .NB-feeds-header-river-blurblogs .NB-feedlist-collapse-icon": "collapse_river_blurblog",
        "click .NB-feeds-header-river-blurblogs": "open_river_blurblogs_stories"
    },
    
    initialize: function() {},
    
    // ===========
    // = Actions =
    // ===========
    
    check_river_blurblog_collapsed: function(options) {
        options = options || {};
        var show_folder_counts = NEWSBLUR.assets.preference('folder_counts');
        var collapsed = _.contains(NEWSBLUR.Preferences.collapsed_folders, 'river_blurblog');

        if (collapsed || show_folder_counts) {
            this.show_collapsed_river_blurblog_count(options);
        }
        
        return collapsed;
    },
    
    show_collapsed_river_blurblog_count: function(options) {
        options = options || {};
        var $header = this.$('.NB-feeds-header-river-blurblogs');
        var $counts = $('.feed_counts_floater', $header);
        var $river = $('.NB-feedlist-collapse-icon', $header);
        var $folder = this.$('.NB-socialfeeds-folder');
        
        $header.addClass('NB-folder-collapsed');
        $counts.remove();
        
        if (!options.skip_animation) {
            // $river.animate({'opacity': 0}, {'duration': options.skip_animation ? 0 : 100});
            $header.addClass('NB-feedlist-folder-title-recently-collapsed');
            $header.one('mouseover', function() {
                $river.css({'opacity': ''});
                $header.removeClass('NB-feedlist-folder-title-recently-collapsed');
            });
        } else {
            $folder.css({
                display: 'none',
                opacity: 0
            });
        }
        
        var $counts = new NEWSBLUR.Views.FolderCount({
            collection: NEWSBLUR.assets.social_feeds
        }).render().$el;
        
        if (this.options.feedbar) {
            this.$('.NB-story-title-indicator-count').html($counts.clone());
        } else {
            $header.prepend($counts.css({
                'opacity': 0
            }));
        }
        $counts.animate({'opacity': 1}, {'duration': options.skip_animation ? 0 : 400});
    },
    
    hide_collapsed_river_blurblog_count: function() {
        var $header = this.$('.NB-feeds-header-river-blurblogs');
        var $counts = $('.feed_counts_floater', $header);
        var $river = $('.NB-feedlist-collapse-icon', $header);
        
        $counts.animate({'opacity': 0}, {
            'duration': 300 
        });
        
        $river.animate({'opacity': .6}, {'duration': 400});
        $header.removeClass('NB-feedlist-folder-title-recently-collapsed');
        $header.one('mouseover', function() {
            $river.css({'opacity': ''});
            $header.removeClass('NB-feedlist-folder-title-recently-collapsed');
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    open_starred_stories: function() {
        return NEWSBLUR.reader.open_starred_stories();
    },
    
    open_river_stories: function() {
        return NEWSBLUR.reader.open_river_stories();
    },
    
    collapse_river_blurblog: function(e, options) {
        e.stopPropagation();
        options = options || {};
        
        var $header = this.$('.NB-feeds-header-river-blurblogs');
        var $folder = this.$('.NB-socialfeeds-folder');
        
        // Hiding / Collapsing
        if (options.force_collapse || 
            ($folder.length && 
             $folder.eq(0).is(':visible'))) {
            NEWSBLUR.assets.collapsed_folders('river_blurblog', true);
            $header.addClass('NB-folder-collapsed');
            $folder.animate({'opacity': 0}, {
                'queue': false,
                'duration': options.force_collapse ? 0 : 200,
                'complete': _.bind(function() {
                    this.show_collapsed_river_blurblog_count();
                    $folder.slideUp({
                        'duration': 270,
                        'easing': 'easeOutQuart'
                    });
                }, this)
            });
        } 
        // Showing / Expanding
        else if ($folder.length && 
                 (!$folder.eq(0).is(':visible'))) {
            NEWSBLUR.assets.collapsed_folders('river_blurblog', false);
            $header.removeClass('NB-folder-collapsed');
            if (!NEWSBLUR.assets.preference('folder_counts')) {
                this.hide_collapsed_river_blurblog_count();
            }
            $folder.css({'opacity': 0}).slideDown({
                'duration': 240,
                'easing': 'easeInOutCubic',
                'complete': function() {
                    $folder.animate({'opacity': 1}, {'queue': false, 'duration': 200});
                }
            });
        }
        
        return false;
    },
    
    open_river_blurblogs_stories: function() {
        return NEWSBLUR.reader.open_river_blurblogs_stories();
    }
    
});