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
        'show_markscroll': true,
        'show_readfilter': true,
        'show_contentpreview': true,
        'show_imagepreview': true,
        'show_order': true
    },
    
    events: {
        "click .NB-view-setting-option": "change_view_setting",
        "click .NB-filter-popover-filter-icon": "open_site_settings",
        "click .NB-filter-popover-stats-icon": "open_site_statistics",
        "click .NB-filter-popover-notifications-icon": "open_notifications",
        "change .NB-modal-feed-chooser": "change_feed"
    },
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        this.options.offset.left = -1 * $(this.options.anchor).width() - 31;
        
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
    
    close: function () {
        if (this.options.on_dashboard) {
            this.options.on_dashboard.$(".NB-feedbar-options").removeClass('NB-active');
        } else {
            NEWSBLUR.app.story_titles_header.$(".NB-feedbar-options").removeClass('NB-active');
        }
        NEWSBLUR.ReaderPopover.prototype.close.apply(this, arguments);
    },

    render: function() {
        var self = this;
        var feed = NEWSBLUR.assets.active_feed;
        if (this.options.feed_id) {
            feed = NEWSBLUR.assets.get_feed(this.options.feed_id)
        }
        var is_feed = feed && feed.is_feed();
        
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        
        this.$el.html($.make('div', [
            (this.options.on_dashboard && $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-modal-feed-chooser-container'}, [
                    NEWSBLUR.utils.make_feed_chooser({
                        feed_id: this.options.feed_id,
                        selected_folder_title: this.options.feed_id,
                        include_folders: true,
                        toplevel: "All Site Stories",
                        include_special_folders: true
                    })
                ])
            ])),
            $.make('div', { className: 'NB-popover-section' }, [
                (is_feed && $.make('div', { className: 'NB-section-icon NB-filter-popover-filter-icon' })),
                $.make('div', { className: 'NB-popover-section-title' }, 'Filter stories'),
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
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, 'Display options'),
                (this.options.show_markscroll && $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-markscroll' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-markscroll-read NB-active' }, 'Read on scroll'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-markscroll-unread' }, 'Leave unread')
                ])),
                (this.options.show_contentpreview && $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-contentpreview' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-contentpreview-title' }, 'Title only'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-contentpreview-small' }, $.make('div', { className: 'NB-icon' })),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-contentpreview-medium' }, $.make('div', { className: 'NB-icon' })),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-contentpreview-large' }, $.make('div', { className: 'NB-icon' })),
                ])),
                (this.options.show_imagepreview && $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-imagepreview' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-imagepreview-none' }, 'No image'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-imagepreview-small' }, 'Small'),
                    $.make('li', { className: 'NB-view-setting-option NB-view-setting-imagepreview-large' }, 'Large'),
                ])),
                $.make('ul', { className: 'segmented-control NB-options-feed-font-size' }, [
                    $.make('li', { className: 'NB-view-setting-option NB-options-font-size-xs' }, 'XS'),
                    $.make('li', { className: 'NB-view-setting-option NB-options-font-size-s' }, 'S'),
                    $.make('li', { className: 'NB-view-setting-option NB-options-font-size-m NB-active' }, 'M'),
                    $.make('li', { className: 'NB-view-setting-option NB-options-font-size-l' }, 'L'),
                    $.make('li', { className: 'NB-view-setting-option NB-options-font-size-xl' }, 'XL')
                ])
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
        var mark_scroll = NEWSBLUR.assets.preference('mark_read_on_scroll_titles');
        var image_preview = NEWSBLUR.assets.preference('show_image_preview');
        var content_preview = NEWSBLUR.assets.preference('show_content_preview');
        var infrequent = parseInt(NEWSBLUR.assets.preference('infrequent_stories_per_month'), 10);
        var feed_font_size = NEWSBLUR.assets.preference('feed_size');

        var $oldest = this.$('.NB-view-setting-order-oldest');
        var $newest = this.$('.NB-view-setting-order-newest');
        var $unread = this.$('.NB-view-setting-readfilter-unread');
        var $all = this.$('.NB-view-setting-readfilter-all');
        var $mark_unread = this.$('.NB-view-setting-markscroll-unread');
        var $mark_read = this.$('.NB-view-setting-markscroll-read');
        var $content_preview_title = this.$('.NB-view-setting-contentpreview-title');
        var $content_preview_1 = this.$('.NB-view-setting-contentpreview-small');
        var $content_preview_2 = this.$('.NB-view-setting-contentpreview-medium');
        var $content_preview_3 = this.$('.NB-view-setting-contentpreview-large');
        var $image_preview_title = this.$('.NB-view-setting-imagepreview-none');
        var $image_preview_1 = this.$('.NB-view-setting-imagepreview-small');
        var $image_preview_2 = this.$('.NB-view-setting-imagepreview-large');
        
        $oldest.toggleClass('NB-active', order == 'oldest');
        $newest.toggleClass('NB-active', order != 'oldest');
        $oldest.text('Oldest' + (order == 'oldest' ? ' first' : ''));
        $newest.text('Newest' + (order != 'oldest' ? ' first' : ''));
        $unread.toggleClass('NB-active', read_filter == 'unread');
        $all.toggleClass('NB-active', read_filter != 'unread');
        $mark_unread.toggleClass('NB-active', !mark_scroll);
        $mark_read.toggleClass('NB-active', mark_scroll);
        $content_preview_title.toggleClass('NB-active', content_preview == '0' || content_preview == "title");
        $content_preview_1.toggleClass('NB-active', content_preview == "small");
        $content_preview_2.toggleClass('NB-active', content_preview == "1" || content_preview == "medium");
        $content_preview_3.toggleClass('NB-active', content_preview == "large");
        $image_preview_title.toggleClass('NB-active', image_preview == "0" || image_preview == "none");
        $image_preview_1.toggleClass('NB-active', image_preview == "small");
        $image_preview_2.toggleClass('NB-active', image_preview == "1" || image_preview == "large");
        this.$('.NB-options-feed-font-size li').removeClass('NB-active');
        this.$('.NB-options-feed-font-size .NB-options-font-size-'+feed_font_size).addClass('NB-active');

        var frequencies = [5, 15, 30, 60, 90];
        for (var f in frequencies) {
            var freq = frequencies[f];
            var $infrequent = this.$('.NB-view-setting-infrequent-' + freq);
            $infrequent.toggleClass('NB-active', infrequent == freq);
            $infrequent.text(infrequent == freq ? '< '+freq+' stories/month' : freq);
        }
        
        if (this.options.on_dashboard) {
            this.options.on_dashboard.$(".NB-feedbar-options").addClass('NB-active');
            this.$('option[value="' + this.options.feed_id + '"]').attr('selected', true);
        } else {
            NEWSBLUR.app.story_titles_header.$(".NB-feedbar-options").addClass('NB-active');
        }
    },

    
    // ==========
    // = Events =
    // ==========
    
    change_view_setting: function(e) {
        var $target = $(e.currentTarget);
        var options = {};
        
        if ($target.hasClass("NB-view-setting-order-newest")) {
            options = {order: 'newest'};
        } else if ($target.hasClass("NB-view-setting-order-oldest")) {
            options = {order: 'oldest'};
        } else if ($target.hasClass("NB-view-setting-readfilter-all")) {
            options = {read_filter: 'all'};
        } else if ($target.hasClass("NB-view-setting-readfilter-unread")) {
            options = {read_filter: 'unread'};
        } else if ($target.hasClass("NB-view-setting-markscroll-unread")) {
            NEWSBLUR.assets.preference('mark_read_on_scroll_titles', false);
        } else if ($target.hasClass("NB-view-setting-markscroll-read")) {
            NEWSBLUR.assets.preference('mark_read_on_scroll_titles', true);
        } else if ($target.hasClass("NB-view-setting-contentpreview-title")) {
            NEWSBLUR.assets.preference('show_content_preview', "title");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-contentpreview-small")) {
            NEWSBLUR.assets.preference('show_content_preview', "small");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-contentpreview-medium")) {
            NEWSBLUR.assets.preference('show_content_preview', "medium");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-contentpreview-large")) {
            NEWSBLUR.assets.preference('show_content_preview', "large");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-imagepreview-none")) {
            NEWSBLUR.assets.preference('show_image_preview', "none");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-imagepreview-small")) {
            NEWSBLUR.assets.preference('show_image_preview', "small");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-imagepreview-large")) {
            NEWSBLUR.assets.preference('show_image_preview', "large");
            NEWSBLUR.reader.apply_story_styling(true);
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
        } else if ($target.hasClass("NB-options-font-size-xs")) {
            this.update_feed_font_size('xs');
        } else if ($target.hasClass("NB-options-font-size-s")) {
            this.update_feed_font_size('s');
        } else if ($target.hasClass("NB-options-font-size-m")) {
            this.update_feed_font_size('m');
        } else if ($target.hasClass("NB-options-font-size-l")) {
            this.update_feed_font_size('l');
        } else if ($target.hasClass("NB-options-font-size-xl")) {
            this.update_feed_font_size('xl');
        }
        
        if (NEWSBLUR.reader.flags.search) {
            options.search = NEWSBLUR.reader.flags.search;
        }
        this.update_feed(options);
        this.show_correct_feed_view_options_in_menu();
    },
    
    update_feed_font_size: function(setting) {
        NEWSBLUR.assets.preference('feed_size', setting);
        NEWSBLUR.reader.apply_story_styling();
    },
    
    update_feed: function(setting) {
        var changed = NEWSBLUR.assets.view_setting(this.options.feed_id, setting);
        if (!changed) return;
        
        if (this.options.on_dashboard) {
            this.options.on_dashboard.initialize();
        } else {
            NEWSBLUR.reader.reload_feed(setting);
        }
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
    },

    change_feed: function () {
        var feed_id = this.$(".NB-modal-feed-chooser").val();
        console.log(['Changing feed', feed_id])
        this.options.on_dashboard.model.change_feed(feed_id);
        this.close();
    }

    
});
