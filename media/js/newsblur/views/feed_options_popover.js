NEWSBLUR.FeedOptionsPopover = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-filter-popover",
    
    options: {
        'width': 304,
        'anchor': '.NB-feedbar-options',
        'placement': 'bottom right',
        'offset': {
            top: 18,
            left: -110
        },
        'overlay_top': true,
        'popover_class': 'NB-filter-popover-container',
        'show_readfilter': true,
        'show_order': true
    },
    
    events: {
        "click .NB-view-setting-option": "change_view_setting",
        "click .NB-filter-popover-filter-icon": "open_site_settings",
        "click .NB-filter-popover-stats-icon": "open_site_statistics",
        "click .NB-filter-popover-notifications-icon": "open_notifications"
    },
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        this.options.offset.left = -1 * $(".NB-feedbar-options").width() - 16;
        
        if (NEWSBLUR.reader.active_feed == "read") {
            this.options['show_readfilter'] = false;
        }
        if (NEWSBLUR.reader.active_feed == "river:infrequent") {
            this.options['show_infrequent'] = true;
        }
        if (NEWSBLUR.reader.flags['starred_view']) {
            this.options.feed_id = "starred"; // Ignore tags
            this.options['show_readfilter'] = false;
        }
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
        var is_feed = feed && feed.is_feed();
        
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        
        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-popover-section' }, [
                (is_feed && $.make('div', { className: 'NB-section-icon NB-filter-popover-filter-icon' })),
                $.make('div', { className: 'NB-popover-section-title' }, 'Filter Options'),
                (this.options.show_readfilter && $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-readfilter' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-readfilter-all  NB-active' }, 'All stories'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-readfilter-unread' }, 'Unread only')
                ])),
                (this.options.show_order && $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-order' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-order-newest NB-active' }, 'Newest first'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-order-oldest' }, 'Oldest')
                ])),
                (this.options.show_infrequent && $.make('div', { className: 'NB-popover-section-title' }, 'Infrequent stories per month')),
                (this.options.show_infrequent && $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-infrequent' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-5' }, '5'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-15' }, '15'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-30 NB-active' }, '< 30 stories/month'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-60' }, '60'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-90' }, '90')
                ]))
            ]),
            (is_feed && $.make('div', { className: 'NB-popover-section' }, [
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
                (feed.get('average_stories_per_month') && $.make('div', { className: 'NB-feedbar-options-stat NB-stat-average' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('div', { className: 'NB-stat' }, Inflector.pluralize("story", feed.get('average_stories_per_month'), true) + " per month")
                ])),
                (feed.get('updated') && $.make('div', { className: 'NB-feedbar-options-stat NB-stat-updated' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('div', { className: 'NB-stat' }, "Updated " + feed.get('updated') + ' ago')
                ])),
                (feed.get('min_to_decay') && $.make('div', { className: 'NB-feedbar-options-stat NB-stat-decay' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('div', { className: 'NB-stat' }, "Fetched every " + NEWSBLUR.utils.calculate_update_interval(feed.get('min_to_decay')))
                ]))
            ])),
            (is_feed && $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-section-icon NB-filter-popover-notifications-icon' }),
                $.make('div', { className: 'NB-popover-section-title' }, 'Notifications'),
                $.make('div', { className: 'NB-feedbar-options-notifications' }, [
                    new NEWSBLUR.Views.FeedNotificationView({model: feed, popover: true}).render().$el
                ])
            ]))
        ]));
        
        return this;
    },
    
    show_correct_feed_view_options_in_menu: function() {
        var order = NEWSBLUR.assets.view_setting(this.options.feed_id, 'order');
        var read_filter = NEWSBLUR.assets.view_setting(this.options.feed_id, 'read_filter');
        var infrequent = parseInt(NEWSBLUR.assets.preference('infrequent_stories_per_month'), 10);
        
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
        
        var frequencies = [5, 15, 30, 60, 90];
        for (var f in frequencies) {
            var freq = frequencies[f];
            var $infrequent = this.$('.NB-view-setting-infrequent-' + freq);
            $infrequent.toggleClass('NB-active', infrequent == freq);
            $infrequent.text(infrequent == freq ? '< '+freq+' stories/month' : freq);
        }
        
        NEWSBLUR.app.story_titles_header.$(".NB-feedbar-options").addClass('NB-active');
    },

    
    // ==========
    // = Events =
    // ==========
    
    change_view_setting: function(e) {
        var $target = $(e.target);
        var options = {};
        
        if ($target.hasClass("NB-view-setting-order-newest")) {
            options = {order: 'newest'};
        } else if ($target.hasClass("NB-view-setting-order-oldest")) {
            options = {order: 'oldest'};
        } else if ($target.hasClass("NB-view-setting-readfilter-all")) {
            options = {read_filter: 'all'};
        } else if ($target.hasClass("NB-view-setting-readfilter-unread")) {
            options = {read_filter: 'unread'};
        } else if ($target.hasClass("NB-view-setting-infrequent-5")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 5);
            NEWSBLUR.reader.reload_feed();
        } else if ($target.hasClass("NB-view-setting-infrequent-15")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 15);
            NEWSBLUR.reader.reload_feed();
        } else if ($target.hasClass("NB-view-setting-infrequent-30")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 30);
            NEWSBLUR.reader.reload_feed();
        } else if ($target.hasClass("NB-view-setting-infrequent-60")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 60);
            NEWSBLUR.reader.reload_feed();
        } else if ($target.hasClass("NB-view-setting-infrequent-90")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 90);
            NEWSBLUR.reader.reload_feed();
        }
        
        if (NEWSBLUR.reader.flags.search) {
            options.search = NEWSBLUR.reader.flags.search;
        }
        this.update_feed(options);
        this.show_correct_feed_view_options_in_menu();
    },
    
    update_feed: function(setting) {
        var changed = NEWSBLUR.assets.view_setting(this.options.feed_id, setting);
        if (!changed) return;
        
        NEWSBLUR.reader.reload_feed(setting);
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
    },

    open_notifications: function() {
        this.close(_.bind(function() {
            NEWSBLUR.reader.open_notifications_modal(this.options.feed_id);
        }, this));
    }

    
});