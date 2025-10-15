NEWSBLUR.FeedOptionsPopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-filter-popover",

    options: {
        'width': 354,
        'anchor': '.NB-feedbar-options',
        'placement': 'bottom right',
        'offset': {
            top: 18,
            left: -110
        },
        'overlay_top': true,
        'popover_class': 'NB-filter-popover-container',
        'show_markscroll': true,
        'show_density': true,
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
        "click .NB-filter-popover-dashboard-add-module-left": "add_dashboard_module_left",
        "click .NB-filter-popover-dashboard-add-module-right": "add_dashboard_module_right",
        "click .NB-filter-popover-dashboard-remove-module": "remove_dashboard_module",
        "change .NB-modal-feed-chooser": "change_feed",
        "input .NB-date-input": "debounced_change_date_range",
        "blur .NB-date-input": "on_date_input_blur",
        "click .NB-clear-date-button": "clear_date_range",
        "click .NB-date-filter-duration": "change_date_filter_duration"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        this.options.offset.left = -1 * $(this.options.anchor).width() - 31;

        if (NEWSBLUR.reader.active_feed == "read") {
            this.options['show_readfilter'] = false;
        }
        if (_.contains([NEWSBLUR.reader.active_feed, this.options.feed_id], "river:infrequent")) {
            this.options['show_infrequent'] = true;
        }
        if (NEWSBLUR.reader.flags['starred_view']) {
            this.options.feed_id = "starred"; // Ignore tags
            this.options['show_readfilter'] = false;
        }

        // console.log("Opening feed options", this.options, this.options.feed_id);

        // Initialize cached date filter state for debouncing
        this.cached_date_filter_start = NEWSBLUR.reader.flags.date_filter_start || '';
        this.cached_date_filter_end = NEWSBLUR.reader.flags.date_filter_end || '';

        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.model = NEWSBLUR.assets;
        this.render();
        this.set_date_inputs_from_model();
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

    render: function () {
        var self = this;
        var feed = NEWSBLUR.assets.active_feed;
        var is_river = _.string.contains(this.options.feed_id || NEWSBLUR.reader.active_feed, 'river:');

        if (this.options.feed_id) {
            if (is_river) {
                feed = NEWSBLUR.reader.active_folder;
            } else {
                feed = NEWSBLUR.assets.get_feed(this.options.feed_id);
            }
        }
        var is_feed = feed && feed.is_feed && feed.is_feed();

        NEWSBLUR.ReaderPopover.prototype.render.call(this);

        this.$el.html($.make('div', [
            (this.options.on_dashboard && $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-modal-feed-chooser-container' }, [
                    NEWSBLUR.utils.make_feed_chooser({
                        feed_id: this.options.feed_id,
                        selected_folder_title: this.options.feed_id,
                        include_folders: true,
                        toplevel: "All Site Stories",
                        include_special_folders: true
                    })
                ]),
                $.make('div', { className: 'NB-filter-popover-manage-dashboard-modules' }, [
                    $.make('div', { className: 'NB-filter-popover-manage-button NB-filter-popover-dashboard-add-module-left' }, [
                        $.make('div', { className: 'NB-icon' }),
                        $.make('div', { className: 'NB-text' }, "Add story list")
                    ]),
                    $.make('div', { className: 'NB-filter-popover-manage-button NB-filter-popover-dashboard-add-module-right' }, [
                        $.make('div', { className: 'NB-icon' }),
                        $.make('div', { className: 'NB-text' }, "Add story list")
                    ])
                ]),
                $.make('div', { className: 'NB-filter-popover-manage-dashboard-modules' }, [
                    $.make('div', { className: 'NB-filter-popover-manage-button NB-filter-popover-dashboard-remove-module' }, [
                        $.make('div', { className: 'NB-icon' }),
                        $.make('div', { className: 'NB-text' }, "Remove this list")
                    ]),
                ])
            ])),
            $.make('div', { className: 'NB-popover-section' }, [
                (is_feed && $.make('div', { className: 'NB-section-icon NB-filter-popover-filter-icon' })),
                $.make('div', { className: 'NB-popover-section-title' }, 'Filter stories'),
                (this.options.on_dashboard && $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-dashboardcount' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-dashboardcount' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-dashboardcount-5  NB-active', role: "button" }, '5 stories'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-dashboardcount-10', role: "button" }, '10'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-dashboardcount-15', role: "button" }, '15'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-dashboardcount-20', role: "button" }, '20'),
                    ])
                ])),
                (this.options.show_readfilter && $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-readfilter' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-readfilter' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-readfilter-all  NB-active', role: "button" }, 'All stories'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-readfilter-unread', role: "button" }, 'Unread only')
                    ])
                ])),
                (this.options.show_order && $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-order' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-order' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-order-newest NB-active', role: "button" }, 'Newest first'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-order-oldest', role: "button" }, 'Oldest')
                    ])
                ])),
                (this.options.show_infrequent && $.make('div', { className: 'NB-popover-section-title' }, 'Infrequent stories per month')),
                (this.options.show_infrequent && $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-infrequent' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-infrequent' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-5', role: "button" }, '5'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-15', role: "button" }, '15'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-30 NB-active', role: "button" }, '< 30 stories/month'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-60', role: "button" }, '60'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-infrequent-90', role: "button" }, '90')
                    ])
                ])),
                $.make('div', { className: 'NB-popover-section-title' }, 'Filter by date range'),
                $.make('div', { className: 'NB-date-filter-container' }, [
                    $.make('div', { className: 'NB-date-filter-column' }, [
                        $.make('div', { className: 'NB-date-filter-label' }, 'Newer:'),
                        $.make('input', {
                            type: 'date',
                            className: 'NB-date-input NB-date-start',
                            placeholder: 'YYYY-MM-DD',
                            autocomplete: 'off'
                        }),
                        $.make('ul', { className: 'segmented-control NB-menu-manage-date-filter-start' }, [
                            $.make('li', { className: 'NB-date-filter-duration NB-date-filter-start-1day', role: "button" }, '1d'),
                            $.make('li', { className: 'NB-date-filter-duration NB-date-filter-start-1week', role: "button" }, '1w'),
                            $.make('li', { className: 'NB-date-filter-duration NB-date-filter-start-1month', role: "button" }, '1m'),
                            $.make('li', { className: 'NB-date-filter-duration NB-date-filter-start-1year', role: "button" }, '1y')
                        ])
                    ]),
                    $.make('div', { className: 'NB-date-filter-column' }, [
                        $.make('div', { className: 'NB-date-filter-label' }, 'Older:'),
                        $.make('input', {
                            type: 'date',
                            className: 'NB-date-input NB-date-end',
                            placeholder: 'YYYY-MM-DD',
                            autocomplete: 'off'
                        }),
                        $.make('ul', { className: 'segmented-control NB-menu-manage-date-filter-end' }, [
                            $.make('li', { className: 'NB-date-filter-duration NB-date-filter-end-1day', role: "button" }, '1d'),
                            $.make('li', { className: 'NB-date-filter-duration NB-date-filter-end-1week', role: "button" }, '1w'),
                            $.make('li', { className: 'NB-date-filter-duration NB-date-filter-end-1month', role: "button" }, '1m'),
                            $.make('li', { className: 'NB-date-filter-duration NB-date-filter-end-1year', role: "button" }, '1y')
                        ])
                    ]),
                    $.make('div', { className: 'NB-clear-date-button' })
                ])
            ]),
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, 'Story title styling'),
                (this.options.show_markscroll && $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-markscroll' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-markscroll' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-markscroll-read NB-active', role: "button" }, 'Read on scroll'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-markscroll-unread', role: "button" }, 'Leave unread')
                    ])
                ])),
                (this.options.show_density && $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-density' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-density' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-density-compact NB-active', role: "button" }, 'Compact'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-density-comfortable', role: "button" }, 'Comfortable')
                    ])
                ])),
                (this.options.show_contentpreview && $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-contentpreview' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-contentpreview' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-contentpreview-title', role: "button" }, 'Title only'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-contentpreview-small', role: "button" }, $.make('div', { className: 'NB-icon' })),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-contentpreview-medium', role: "button" }, $.make('div', { className: 'NB-icon' })),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-contentpreview-large', role: "button" }, $.make('div', { className: 'NB-icon' })),
                    ])
                ])),
                (this.options.show_imagepreview && $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-imagepreview' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-view-setting-imagepreview' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-imagepreview-none', role: "button" }, 'No image'),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-imagepreview-small-left', role: "button" }, [
                            $.make('img', { className: 'NB-icon', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/image_preview_small_left.png' })
                        ]),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-imagepreview-large-left', role: "button" }, [
                            $.make('img', { className: 'NB-icon', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/image_preview_large_left.png' })
                        ]),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-imagepreview-large-right', role: "button" }, [
                            $.make('img', { className: 'NB-icon', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/image_preview_large_right.png' })
                        ]),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-imagepreview-small-right', role: "button" }, [
                            $.make('img', { className: 'NB-icon', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/image_preview_small_right.png' })
                        ])
                    ])
                ])),
                $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-feed-font' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-options-feed-font' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-feed-font-whitney NB-theme-feed-font-whitney', role: "button" }, [
                            $.make('div', { className: 'NB-icon' }),
                            'Whitney'
                        ]),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-feed-font-lucida NB-theme-feed-font-lucida', role: "button" }, [
                            $.make('div', { className: 'NB-icon' }),
                            'Lucida'
                        ]),
                        $.make('li', { className: 'NB-view-setting-option NB-view-setting-feed-font-gotham NB-theme-feed-font-gotham', role: "button" }, [
                            $.make('div', { className: 'NB-icon' }),
                            'Gotham'
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-popover-icon-control NB-popover-icon-control-feed-size' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('ul', { className: 'segmented-control NB-options-feed-size' }, [
                        $.make('li', { className: 'NB-view-setting-option NB-options-feed-size-xs', role: "button" }, 'XS'),
                        $.make('li', { className: 'NB-view-setting-option NB-options-feed-size-s', role: "button" }, 'S'),
                        $.make('li', { className: 'NB-view-setting-option NB-options-feed-size-m NB-active', role: "button" }, 'M'),
                        $.make('li', { className: 'NB-view-setting-option NB-options-feed-size-l', role: "button" }, 'L'),
                        $.make('li', { className: 'NB-view-setting-option NB-options-feed-size-xl', role: "button" }, 'XL')
                    ])
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
                (feed.get('archive_count') && $.make('div', { className: 'NB-feedbar-options-stat NB-stat-archive-count' }, [
                    $.make('div', { className: 'NB-icon' }),
                    $.make('div', { className: 'NB-stat' }, Inflector.pluralize("story", feed.get('archive_count'), true) + " in archive")
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
                    new NEWSBLUR.Views.FeedNotificationView({ model: feed, popover: true }).render().$el
                ])
            ]))
        ]));

        return this;
    },

    set_date_inputs_from_model: function () {
        var date_filter_start = NEWSBLUR.reader.flags.date_filter_start;
        var date_filter_end = NEWSBLUR.reader.flags.date_filter_end;

        // Set date inputs to the date_filter values if they exist
        if (date_filter_start) {
            this.$('.NB-date-start').val(date_filter_start);
        } else {
            this.$('.NB-date-start').val('');
        }
        if (date_filter_end) {
            this.$('.NB-date-end').val(date_filter_end);
        } else {
            this.$('.NB-date-end').val('');
        }
    },

    update_date_ui: function () {
        // Read actual input values
        var start_date = this.$('.NB-date-start').val() || '';
        var end_date = this.$('.NB-date-end').val() || '';

        // Update clear button visibility based on actual input values
        this.$('.NB-date-filter-container').toggleClass('NB-has-dates', !!(start_date || end_date));

        // Update segmented controls based on whether inputs match presets
        var $date_filter_start_1day = this.$('.NB-date-filter-start-1day');
        var $date_filter_start_1week = this.$('.NB-date-filter-start-1week');
        var $date_filter_start_1month = this.$('.NB-date-filter-start-1month');
        var $date_filter_start_1year = this.$('.NB-date-filter-start-1year');
        var $date_filter_end_1day = this.$('.NB-date-filter-end-1day');
        var $date_filter_end_1week = this.$('.NB-date-filter-end-1week');
        var $date_filter_end_1month = this.$('.NB-date-filter-end-1month');
        var $date_filter_end_1year = this.$('.NB-date-filter-end-1year');

        $date_filter_start_1day.toggleClass('NB-active', this.is_date_filter_for_days(start_date, 1));
        $date_filter_start_1week.toggleClass('NB-active', this.is_date_filter_for_days(start_date, 7));
        $date_filter_start_1month.toggleClass('NB-active', this.is_date_filter_for_days(start_date, 30));
        $date_filter_start_1year.toggleClass('NB-active', this.is_date_filter_for_days(start_date, 365));
        $date_filter_end_1day.toggleClass('NB-active', this.is_date_filter_for_days(end_date, 1));
        $date_filter_end_1week.toggleClass('NB-active', this.is_date_filter_for_days(end_date, 7));
        $date_filter_end_1month.toggleClass('NB-active', this.is_date_filter_for_days(end_date, 30));
        $date_filter_end_1year.toggleClass('NB-active', this.is_date_filter_for_days(end_date, 365));
    },

    show_correct_feed_view_options_in_menu: function () {
        var order = NEWSBLUR.assets.view_setting(this.options.feed_id, 'order');
        var read_filter = NEWSBLUR.assets.view_setting(this.options.feed_id, 'read_filter');
        var dashboard_count = parseInt(NEWSBLUR.assets.view_setting(this.options.feed_id, 'dashboard_count'), 10);
        var mark_scroll = NEWSBLUR.assets.preference('mark_read_on_scroll_titles');
        var density = NEWSBLUR.assets.preference('density');
        var image_preview = NEWSBLUR.assets.preference('image_preview');
        var content_preview = NEWSBLUR.assets.preference('show_content_preview');
        var infrequent = parseInt(NEWSBLUR.assets.preference('infrequent_stories_per_month'), 10);
        var feed_size = NEWSBLUR.assets.preference('feed_size');
        var feed_font = NEWSBLUR.assets.preference('feed_font');

        var $oldest = this.$('.NB-view-setting-order-oldest');
        var $newest = this.$('.NB-view-setting-order-newest');
        var $unread = this.$('.NB-view-setting-readfilter-unread');
        var $all = this.$('.NB-view-setting-readfilter-all');
        var $count5 = this.$('.NB-view-setting-dashboardcount-5');
        var $count10 = this.$('.NB-view-setting-dashboardcount-10');
        var $count15 = this.$('.NB-view-setting-dashboardcount-15');
        var $count20 = this.$('.NB-view-setting-dashboardcount-20');
        var $mark_unread = this.$('.NB-view-setting-markscroll-unread');
        var $mark_read = this.$('.NB-view-setting-markscroll-read');
        var $density_compact = this.$('.NB-view-setting-density-compact');
        var $density_comfortable = this.$('.NB-view-setting-density-comfortable');
        var $content_preview_title = this.$('.NB-view-setting-contentpreview-title');
        var $content_preview_1 = this.$('.NB-view-setting-contentpreview-small');
        var $content_preview_2 = this.$('.NB-view-setting-contentpreview-medium');
        var $content_preview_3 = this.$('.NB-view-setting-contentpreview-large');
        var $image_preview_title = this.$('.NB-view-setting-imagepreview-none');
        var $image_preview_sl = this.$('.NB-view-setting-imagepreview-small-left');
        var $image_preview_sr = this.$('.NB-view-setting-imagepreview-small-right');
        var $image_preview_ll = this.$('.NB-view-setting-imagepreview-large-left');
        var $image_preview_lr = this.$('.NB-view-setting-imagepreview-large-right');

        $oldest.toggleClass('NB-active', order == 'oldest');
        $newest.toggleClass('NB-active', order != 'oldest');
        $oldest.text('Oldest' + (order == 'oldest' ? ' first' : ''));
        $newest.text('Newest' + (order != 'oldest' ? ' first' : ''));
        $unread.toggleClass('NB-active', read_filter == 'unread');
        $count5.toggleClass('NB-active', dashboard_count == 5);
        $count10.toggleClass('NB-active', dashboard_count == 10);
        $count15.toggleClass('NB-active', dashboard_count == 15);
        $count20.toggleClass('NB-active', dashboard_count == 20);
        $count5.text('5' + (dashboard_count == 5 ? ' stories' : ''));
        $count10.text('10' + (dashboard_count == 10 ? ' stories' : ''));
        $count15.text('15' + (dashboard_count == 15 ? ' stories' : ''));
        $count20.text('20' + (dashboard_count == 20 ? ' stories' : ''));
        $all.toggleClass('NB-active', read_filter != 'unread');
        $mark_unread.toggleClass('NB-active', !mark_scroll);
        $mark_read.toggleClass('NB-active', mark_scroll);
        $density_compact.toggleClass('NB-active', density == "compact");
        $density_comfortable.toggleClass('NB-active', density == "comfortable");
        $content_preview_title.toggleClass('NB-active', content_preview == '0' || content_preview == "title");
        $content_preview_1.toggleClass('NB-active', content_preview == "small");
        $content_preview_2.toggleClass('NB-active', content_preview == "1" || content_preview == "medium");
        $content_preview_3.toggleClass('NB-active', content_preview == "large");
        $image_preview_title.toggleClass('NB-active', image_preview == "0" || image_preview == "none");
        $image_preview_sl.toggleClass('NB-active', image_preview == "small-left");
        $image_preview_sr.toggleClass('NB-active', image_preview == "small-right");
        $image_preview_ll.toggleClass('NB-active', image_preview == "large-left");
        $image_preview_lr.toggleClass('NB-active', image_preview == "1" || image_preview == "large-right");
        this.$('.NB-options-feed-size li').removeClass('NB-active');
        this.$('.NB-options-feed-size .NB-options-feed-size-' + feed_size).addClass('NB-active');
        this.$('.NB-options-feed-font .NB-view-setting-option').removeClass('NB-active');
        this.$('.NB-options-feed-font .NB-view-setting-feed-font-' + feed_font).addClass('NB-active');

        var frequencies = [5, 15, 30, 60, 90];
        for (var f in frequencies) {
            var freq = frequencies[f];
            var $infrequent = this.$('.NB-view-setting-infrequent-' + freq);
            $infrequent.toggleClass('NB-active', infrequent == freq);
            $infrequent.text(infrequent == freq ? '< ' + freq + '/month' : freq);
        }

        if (this.options.on_dashboard) {
            this.options.on_dashboard.$(".NB-feedbar-options").addClass('NB-active');
            this.$('option[value="' + this.options.feed_id + '"]').attr('selected', true);
        } else {
            NEWSBLUR.app.story_titles_header.$(".NB-feedbar-options").addClass('NB-active');
        }

        // Update date filter UI based on actual input values
        this.update_date_ui();
    },


    // ==========
    // = Events =
    // ==========

    change_view_setting: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.currentTarget);
        var options = {};

        if ($target.hasClass("NB-view-setting-order-newest")) {
            options = { order: 'newest' };
        } else if ($target.hasClass("NB-view-setting-order-oldest")) {
            options = { order: 'oldest' };
        } else if ($target.hasClass("NB-view-setting-dashboardcount-5")) {
            options = { dashboard_count: 5 };
        } else if ($target.hasClass("NB-view-setting-dashboardcount-10")) {
            options = { dashboard_count: 10 };
        } else if ($target.hasClass("NB-view-setting-dashboardcount-15")) {
            options = { dashboard_count: 15 };
        } else if ($target.hasClass("NB-view-setting-dashboardcount-20")) {
            options = { dashboard_count: 20 };
        } else if ($target.hasClass("NB-view-setting-readfilter-all")) {
            options = { read_filter: 'all' };
        } else if ($target.hasClass("NB-view-setting-readfilter-unread")) {
            options = { read_filter: 'unread' };
        } else if ($target.hasClass("NB-view-setting-markscroll-unread")) {
            NEWSBLUR.assets.preference('mark_read_on_scroll_titles', false);
        } else if ($target.hasClass("NB-view-setting-markscroll-read")) {
            NEWSBLUR.assets.preference('mark_read_on_scroll_titles', true);
        } else if ($target.hasClass("NB-view-setting-density-compact")) {
            NEWSBLUR.assets.preference('density', "compact");
            NEWSBLUR.reader.apply_story_styling();
        } else if ($target.hasClass("NB-view-setting-density-comfortable")) {
            NEWSBLUR.assets.preference('density', "comfortable");
            NEWSBLUR.reader.apply_story_styling();
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
            NEWSBLUR.assets.preference('image_preview', "none");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-imagepreview-small-left")) {
            NEWSBLUR.assets.preference('image_preview', "small-left");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-imagepreview-small-right")) {
            NEWSBLUR.assets.preference('image_preview', "small-right");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-imagepreview-large-left")) {
            NEWSBLUR.assets.preference('image_preview', "large-left");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-imagepreview-large-right")) {
            NEWSBLUR.assets.preference('image_preview', "large-right");
            NEWSBLUR.reader.apply_story_styling(true);
        } else if ($target.hasClass("NB-view-setting-infrequent-5")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 5);
            this.reload_feed();
        } else if ($target.hasClass("NB-view-setting-infrequent-15")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 15);
            this.reload_feed();
        } else if ($target.hasClass("NB-view-setting-infrequent-30")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 30);
            this.reload_feed();
        } else if ($target.hasClass("NB-view-setting-infrequent-60")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 60);
            this.reload_feed();
        } else if ($target.hasClass("NB-view-setting-infrequent-90")) {
            NEWSBLUR.assets.preference('infrequent_stories_per_month', 90);
            this.reload_feed();
        } else if ($target.hasClass("NB-options-feed-size-xs")) {
            this.update_feed_font_size('xs');
        } else if ($target.hasClass("NB-options-feed-size-s")) {
            this.update_feed_font_size('s');
        } else if ($target.hasClass("NB-options-feed-size-m")) {
            this.update_feed_font_size('m');
        } else if ($target.hasClass("NB-options-feed-size-l")) {
            this.update_feed_font_size('l');
        } else if ($target.hasClass("NB-options-feed-size-xl")) {
            this.update_feed_font_size('xl');
        } else if ($target.hasClass("NB-view-setting-feed-font-whitney")) {
            this.update_feed_font('whitney');
        } else if ($target.hasClass("NB-view-setting-feed-font-lucida")) {
            this.update_feed_font('lucida');
        } else if ($target.hasClass("NB-view-setting-feed-font-gotham")) {
            this.update_feed_font('gotham');
        }

        if (NEWSBLUR.reader.flags.search) {
            options.search = NEWSBLUR.reader.flags.search;
        }
        // Preserve date filters when changing view settings
        if (NEWSBLUR.reader.flags.date_filter_start) {
            options.date_filter_start = NEWSBLUR.reader.flags.date_filter_start;
        }
        if (NEWSBLUR.reader.flags.date_filter_end) {
            options.date_filter_end = NEWSBLUR.reader.flags.date_filter_end;
        }
        this.update_feed(options);
        this.show_correct_feed_view_options_in_menu();
    },

    update_feed_font_size: function (setting) {
        NEWSBLUR.assets.preference('feed_size', setting);
        NEWSBLUR.reader.apply_story_styling();
    },

    update_feed_font: function (setting) {
        NEWSBLUR.assets.preference('feed_font', setting);
        NEWSBLUR.reader.apply_story_styling();
    },

    update_feed: function (setting) {
        var options = {};
        var changed = NEWSBLUR.assets.view_setting(this.options.feed_id, setting);
        if (setting.date_filter_start || setting.date_filter_end) {
            options.date_filter_start = setting.date_filter_start;
            options.date_filter_end = setting.date_filter_end;
        } else if (!changed) {
            return;
        }

        this.reload_feed(options);
    },

    reload_feed: function (options) {
        options = options || {};

        // Preserve date filters by default unless explicitly cleared
        if (!options.hasOwnProperty('date_filter_start') && NEWSBLUR.reader.flags.date_filter_start) {
            options.date_filter_start = NEWSBLUR.reader.flags.date_filter_start;
        }
        if (!options.hasOwnProperty('date_filter_end') && NEWSBLUR.reader.flags.date_filter_end) {
            options.date_filter_end = NEWSBLUR.reader.flags.date_filter_end;
        }

        if (this.options.on_dashboard) {
            this.options.on_dashboard.initialize();
        } else {
            NEWSBLUR.reader.reload_feed(options);
        }
    },

    open_site_settings: function () {
        this.close(function () {
            NEWSBLUR.reader.open_feed_exception_modal();
        });
    },

    open_site_statistics: function () {
        this.close(function () {
            console.log(["stats"]);
            NEWSBLUR.reader.open_feed_statistics_modal();
        });
    },

    open_notifications: function () {
        this.close(_.bind(function () {
            NEWSBLUR.reader.open_notifications_modal(this.options.feed_id);
        }, this));
    },

    add_dashboard_module: function (side) {
        var count = NEWSBLUR.assets.dashboard_rivers.side(side).length;
        var folder_names = NEWSBLUR.assets.folders.child_folder_names();
        var random_feed = "river:";
        if (folder_names.length) {
            random_feed = "river:" + folder_names[_.random(folder_names.length)];;
        }
        NEWSBLUR.assets.save_dashboard_river(random_feed, side, count, _.bind(function () {
            NEWSBLUR.reader.load_dashboard_rivers(true);
            this.close();
        }, this), function (e) {
            console.log(['Error saving dashboard river', e]);
        });
    },

    add_dashboard_module_left: function () {
        this.add_dashboard_module("left");
    },

    add_dashboard_module_right: function () {
        this.add_dashboard_module("right");
    },

    remove_dashboard_module: function () {
        var river_id = this.options.feed_id;
        var river_side = this.options.river_side;
        var river_order = this.options.river_order;
        NEWSBLUR.assets.remove_dashboard_river(river_id, river_side, river_order, _.bind(function () {
            NEWSBLUR.reader.load_dashboard_rivers(true);
            this.close();
        }, this), function (e) {
            console.log(['Error saving dashboard river', e]);
        });
    },

    change_feed: function () {
        var feed_id = this.$(".NB-modal-feed-chooser").val();
        console.log(['Changing feed', feed_id])
        this.options.on_dashboard.model.change_feed(feed_id);
        this.close();
    },

    debounced_change_date_range: function () {
        // Debounce the date range change to avoid hammering the server
        if (this._date_range_debounce_timer) {
            clearTimeout(this._date_range_debounce_timer);
        }

        this._date_range_debounce_timer = setTimeout(_.bind(function () {
            this.change_date_range();
        }, this), 500);
    },

    on_date_input_blur: function () {
        // When user blurs the input, immediately apply the change
        // but only if the value is different from what was last processed
        var start_date = this.$('.NB-date-start').val() || '';
        var end_date = this.$('.NB-date-end').val() || '';

        if (start_date !== this.cached_date_filter_start || end_date !== this.cached_date_filter_end) {
            // Cancel any pending debounced update
            if (this._date_range_debounce_timer) {
                clearTimeout(this._date_range_debounce_timer);
                this._date_range_debounce_timer = null;
            }
            this.change_date_range();
        }
    },

    change_date_range: function () {
        var start_date = this.$('.NB-date-start').val();
        var end_date = this.$('.NB-date-end').val();

        // Validate date range
        if (start_date && end_date) {
            var start = new Date(start_date);
            var end = new Date(end_date);

            if (start > end) {
                // Invalid range: start date is after end date
                console.log('Invalid date range: Start date must be before or equal to end date.');
                return;
            }
        }

        // Update cached state
        this.cached_date_filter_start = start_date || '';
        this.cached_date_filter_end = end_date || '';

        var options = {
            date_filter_start: start_date || null,
            date_filter_end: end_date || null
        };

        this.update_feed(options);
        // Update segmented controls to reflect whether the manual date matches a preset
        this.update_date_ui();
    },

    clear_date_range: function () {
        this.$('.NB-date-start').val('');
        this.$('.NB-date-end').val('');

        // Reset cached state
        this.cached_date_filter_start = '';
        this.cached_date_filter_end = '';

        // Explicitly clear date filters
        this.reload_feed({
            date_filter_start: null,
            date_filter_end: null
        });
        this.update_date_ui();
    },

    change_date_filter_duration: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.currentTarget);
        var options = {};

        if ($target.hasClass("NB-date-filter-start-1day")) {
            var one_day_ago = this.get_date_string(1);
            options = {
                date_filter_start: one_day_ago,
                date_filter_end: null
            };
            this.$('.NB-date-start').val(one_day_ago);
            this.$('.NB-date-end').val('');
        } else if ($target.hasClass("NB-date-filter-start-1week")) {
            var one_week_ago = this.get_date_string(7);
            options = {
                date_filter_start: one_week_ago,
                date_filter_end: null
            };
            this.$('.NB-date-start').val(one_week_ago);
            this.$('.NB-date-end').val('');
        } else if ($target.hasClass("NB-date-filter-start-1month")) {
            var one_month_ago = this.get_date_string(30);
            options = {
                date_filter_start: one_month_ago,
                date_filter_end: null
            };
            this.$('.NB-date-start').val(one_month_ago);
            this.$('.NB-date-end').val('');
        } else if ($target.hasClass("NB-date-filter-start-1year")) {
            var one_year_ago = this.get_date_string(365);
            options = {
                date_filter_start: one_year_ago,
                date_filter_end: null
            };
            this.$('.NB-date-start').val(one_year_ago);
            this.$('.NB-date-end').val('');
        } else if ($target.hasClass("NB-date-filter-end-1day")) {
            var one_day_ago = this.get_date_string(1);
            options = {
                date_filter_start: null,
                date_filter_end: one_day_ago
            };
            this.$('.NB-date-start').val('');
            this.$('.NB-date-end').val(one_day_ago);
        } else if ($target.hasClass("NB-date-filter-end-1week")) {
            var one_week_ago = this.get_date_string(7);
            options = {
                date_filter_start: null,
                date_filter_end: one_week_ago
            };
            this.$('.NB-date-start').val('');
            this.$('.NB-date-end').val(one_week_ago);
        } else if ($target.hasClass("NB-date-filter-end-1month")) {
            var one_month_ago = this.get_date_string(30);
            options = {
                date_filter_start: null,
                date_filter_end: one_month_ago
            };
            this.$('.NB-date-start').val('');
            this.$('.NB-date-end').val(one_month_ago);
        } else if ($target.hasClass("NB-date-filter-end-1year")) {
            var one_year_ago = this.get_date_string(365);
            options = {
                date_filter_start: null,
                date_filter_end: one_year_ago
            };
            this.$('.NB-date-start').val('');
            this.$('.NB-date-end').val(one_year_ago);
        }

        // Update cached state to match the new values
        this.cached_date_filter_start = this.$('.NB-date-start').val() || '';
        this.cached_date_filter_end = this.$('.NB-date-end').val() || '';

        this.update_feed(options);
        this.update_date_ui();
    },

    get_date_string: function (days_ago) {
        var today = new Date();
        var one_day = 24 * 60 * 60 * 1000; // milliseconds in one day
        var past_date = new Date(today.getTime() - days_ago * one_day);
        var formatted_date = past_date.toISOString().split('T')[0];
        return formatted_date;
    },

    is_date_filter_for_days: function (date_filter, days) {
        if (!date_filter) return false;

        var target_date = this.get_date_string(days);
        return date_filter === target_date;
    }

});
