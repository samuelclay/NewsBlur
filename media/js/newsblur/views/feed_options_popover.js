NEWSBLUR.FeedOptionsPopover = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-filter-popover",
    
    options: {
        'width': 264,
        'anchor': '.NB-feedbar-options',
        'placement': 'bottom -left',
        'offset': {
            top: 18,
            left: 0
        },
        'overlay_top': true,
        'popover_class': 'NB-filter-popover-container'
    },
    
    events: {
        "click .NB-view-setting-option": "change_view_setting",
        "click .NB-filter-popover-filter-icon": "open_site_settings",
        "click .NB-filter-popover-stats-icon": "open_site_statistics"
    },
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.model = NEWSBLUR.assets;
        this.render();
        this.show_correct_feed_view_options_in_menu();
    },
    
    close: function() {
        NEWSBLUR.app.story_titles_header.$(".NB-feedbar-options").removeClass('NB-active');
        NEWSBLUR.ReaderPopover.prototype.close.apply(this, arguments);
    },

    render: function() {
        var self = this;
        var feed = NEWSBLUR.assets.active_feed;
        
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        
        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-popover-section' }, [
                (feed && $.make('div', { className: 'NB-section-icon NB-filter-popover-filter-icon' })),
                $.make('div', { className: 'NB-popover-section-title' }, 'Filter Options'),
                $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-readfilter' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-readfilter-all  NB-active' }, 'All stories'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-readfilter-unread' }, 'Unread only')
                ]),
                $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-order' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-order-newest NB-active' }, 'Newest first'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-order-oldest' }, 'Oldest')
                ])
            ]),
            (feed && $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-section-icon NB-filter-popover-stats-icon' }),
                $.make('div', { className: 'NB-popover-section-title' }, 'Site Stats'),
                $.make('div', { className: 'NB-feedbar-options-stat NB-stat-subscribers' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('div', { className: 'NB-stat' }, Inflector.pluralize('subscriber', feed.get('num_subscribers'), true))
                ]),
                (feed.get('is_push') && $.make('div', { className: 'NB-feedbar-options-stat NB-stat-realtime' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('div', { className: 'NB-stat' }, "Stories arrive in real-time")
                ])),
                (feed.get('updated') && $.make('div', { className: 'NB-feedbar-options-stat NB-stat-updated' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('div', { className: 'NB-stat' }, "Updated " + feed.get('updated') + ' ago')
                ])),
                (feed.get('min_to_decay') && $.make('div', { className: 'NB-feedbar-options-stat NB-stat-decay' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('div', { className: 'NB-stat' }, "Fetched every " + NEWSBLUR.utils.calculate_update_interval(feed.get('min_to_decay')))
                ]))
            ]))
        ]));
        
        return this;
    },
    
    show_correct_feed_view_options_in_menu: function() {
        var order = NEWSBLUR.assets.view_setting(this.options.feed_id, 'order');
        var read_filter = NEWSBLUR.assets.view_setting(this.options.feed_id, 'read_filter');
        var $oldest = this.$('.NB-view-setting-order-oldest');
        var $newest = this.$('.NB-view-setting-order-newest');
        var $unread = this.$('.NB-view-setting-readfilter-unread');
        var $all = this.$('.NB-view-setting-readfilter-all');

        $oldest.toggleClass('NB-active', order == 'oldest');
        $newest.toggleClass('NB-active', order != 'oldest');
        $oldest.text('Oldest' + (order == 'oldest' ? ' first' : ''));
        $newest.text('Newest' + (order != 'oldest' ? ' first' : ''));
        $unread.toggleClass('NB-active', read_filter == 'unread');
        $all.toggleClass('NB-active', read_filter != 'unread');

        NEWSBLUR.app.story_titles_header.$(".NB-feedbar-options").addClass('NB-active');
    },

    
    // ==========
    // = Events =
    // ==========
    
    change_view_setting: function(e) {
        var $target = $(e.target);
        
        if ($target.hasClass("NB-view-setting-order-newest")) {
            this.update_feed({order: 'newest'});
        } else if ($target.hasClass("NB-view-setting-order-oldest")) {
            this.update_feed({order: 'oldest'});
        } else if ($target.hasClass("NB-view-setting-readfilter-all")) {
            this.update_feed({read_filter: 'all'});
        } else if ($target.hasClass("NB-view-setting-readfilter-unread")) {
            this.update_feed({read_filter: 'unread'});
        }
        
        this.show_correct_feed_view_options_in_menu();
    },
    
    update_feed: function(setting) {
        var changed = NEWSBLUR.assets.view_setting(this.options.feed_id, setting);
        if (!changed) return;
        
        NEWSBLUR.reader.reload_feed();
    },
    
    open_site_settings: function() {
        this.close(function() {
            NEWSBLUR.reader.open_feed_exception_modal();
        });
    },
    
    open_site_statistics: function() {
        this.close(function() {
            console.log(["stats"]);
            NEWSBLUR.reader.open_feed_statistics_modal();
        });
    }

    
});