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
        "click .NB-filter-popover-auto-mark-read-icon": "open_auto_mark_read",
        "click .NB-filter-popover-dashboard-add-module-left": "add_dashboard_module_left",
        "click .NB-filter-popover-dashboard-add-module-right": "add_dashboard_module_right",
        "click .NB-filter-popover-dashboard-remove-module": "remove_dashboard_module",
        "change .NB-modal-feed-chooser": "change_feed",
        "input .NB-date-input": "debounced_change_date_range",
        "blur .NB-date-input": "on_date_input_blur",
        "click .NB-clear-date-button": "clear_date_range",
        "click .NB-date-filter-duration": "change_date_filter_duration",
        "click .NB-auto-mark-read-option": "change_auto_mark_read_setting",
        "input .NB-auto-mark-read-slider": "on_auto_mark_read_slider_input",
        "click .NB-auto-mark-read-upgrade-notice": "open_premium_modal",
        "click .NB-date-filter-upgrade-notice": "open_premium_modal",
        "click .NB-clustering-upgrade-notice": "open_premium_modal",
        "click .NB-clustering-option": "change_clustering_setting"
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
                $.make('div', { className: 'NB-date-filter-title-row' }, [
                    $.make('div', { className: 'NB-popover-section-title' }, 'Filter by date range'),
                    (!NEWSBLUR.Globals.is_archive && $.make('a', { className: 'NB-date-filter-upgrade-notice NB-premium-link', href: '#' }, [
                        $.make('span', { className: 'NB-archive-badge' }, 'Premium Archive')
                    ]))
                ]),
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
            ])),
            ((is_feed || is_river) && NEWSBLUR.Globals.is_staff && $.make('div', { className: 'NB-popover-section NB-popover-section-clustering' }, [
                $.make('div', { className: 'NB-clustering-title-row' }, [
                    $.make('div', { className: 'NB-popover-section-title' }, 'Story Clustering'),
                    $.make('span', { className: 'NB-staff-only-badge' }, 'STAFF ONLY')
                ]),
                $.make('ul', { className: 'segmented-control NB-menu-manage-clustering-enabled' }, [
                    $.make('li', { className: 'NB-clustering-option NB-clustering-enabled-on', 'data-setting': 'story_clustering', 'data-value': 'true', role: 'button' }, 'Cluster related stories'),
                    $.make('li', { className: 'NB-clustering-option NB-clustering-enabled-off', 'data-setting': 'story_clustering', 'data-value': 'false', role: 'button' }, 'Keep stories separate')
                ]),
                $.make('div', { className: 'NB-clustering-read-section' }, [
                    $.make('div', { className: 'NB-clustering-read-label' }, 'When reading a clustered story:'),
                    $.make('ul', { className: 'segmented-control NB-menu-manage-clustering-read' }, [
                        $.make('li', { className: 'NB-clustering-option NB-clustering-read-on', 'data-setting': 'cluster_mark_read', 'data-value': 'true', role: 'button' }, 'Mark all as read'),
                        $.make('li', { className: 'NB-clustering-option NB-clustering-read-off', 'data-setting': 'cluster_mark_read', 'data-value': 'false', role: 'button' }, 'Keep others unread')
                    ])
                ])
            ])),
            ((is_feed || is_river) && $.make('div', { className: 'NB-popover-section NB-popover-section-auto-mark-read' }, [
                $.make('div', { className: 'NB-auto-mark-read-title-row' }, [
                    $.make('div', { className: 'NB-popover-section-title' }, 'Auto Mark as Read'),
                    (!NEWSBLUR.Globals.is_archive && $.make('a', { className: 'NB-auto-mark-read-upgrade-notice NB-premium-link', href: '#' }, [
                        $.make('span', { className: 'NB-archive-badge' }, 'Premium Archive')
                    ])),
                    $.make('div', { className: 'NB-filter-popover-auto-mark-read-icon' })
                ]),
                $.make('ul', { className: 'segmented-control NB-menu-manage-auto-mark-read' }, [
                    $.make('li', { className: 'NB-auto-mark-read-option NB-auto-mark-read-default', 'data-value': 'default', role: 'button' }, 'Default'),
                    $.make('li', { className: 'NB-auto-mark-read-option NB-auto-mark-read-days', 'data-value': 'days', role: 'button' }, 'Days'),
                    $.make('li', { className: 'NB-auto-mark-read-option NB-auto-mark-read-never', 'data-value': 'never', role: 'button' }, 'Never')
                ]),
                $.make('div', { className: 'NB-auto-mark-read-slider-container' }, [
                    $.make('input', {
                        type: 'range',
                        className: 'NB-auto-mark-read-slider',
                        min: '1',
                        max: '400',
                        value: '14'
                    }),
                    $.make('div', { className: 'NB-auto-mark-read-slider-value' })
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

        // Update clustering UI
        this.update_clustering_ui();

        // Update date filter UI based on actual input values
        this.update_date_ui();

        // Update auto-mark-read UI
        this.update_auto_mark_read_ui();
    },

    update_auto_mark_read_ui: function () {
        var is_river = _.string.contains(this.options.feed_id, 'river:');
        var folder_title = is_river ? this.options.feed_id.replace('river:', '') : null;
        var feed = is_river ? null : NEWSBLUR.assets.get_feed(this.options.feed_id);

        if (!feed && !is_river) return;

        var $default = this.$('.NB-auto-mark-read-default');
        var $never = this.$('.NB-auto-mark-read-never');
        var $days = this.$('.NB-auto-mark-read-days');
        var $slider = this.$('.NB-auto-mark-read-slider');
        var $slider_value = this.$('.NB-auto-mark-read-slider-value');

        // Calculate the default/inherited value
        var site_wide_days = NEWSBLUR.Preferences.days_of_unread || 14;
        var default_days = site_wide_days;
        var default_source = 'site-wide';

        if (!is_river && feed) {
            var folders = NEWSBLUR.assets.get_feed_folders(feed.id);
            var feed_folder_title = folders && folders.length > 0 ? folders[0] : null;
            var folder_setting = feed_folder_title ? NEWSBLUR.assets.get_folder_auto_mark_read(feed_folder_title) : null;

            if (folder_setting !== null && folder_setting !== undefined) {
                default_days = folder_setting;
                default_source = feed_folder_title;
            }
        }

        // For non-archive users, just show Default as active
        if (!NEWSBLUR.Globals.is_archive) {
            $default.addClass('NB-active');
            $never.removeClass('NB-active');
            $days.removeClass('NB-active');
            var display_days = default_days === 0 ? 400 : default_days;
            $slider.val(display_days);
            this.update_slider_status_text($slider_value, 'default', default_days, default_source);
            this.update_slider_gradient($slider, display_days);
            return;
        }

        // Get current setting
        var auto_mark_days;
        if (is_river) {
            auto_mark_days = NEWSBLUR.assets.get_folder_auto_mark_read(folder_title);
        } else {
            auto_mark_days = feed.get('auto_mark_read_days');
        }

        // Clear all active states
        $default.removeClass('NB-active');
        $never.removeClass('NB-active');
        $days.removeClass('NB-active');

        var slider_value;
        var mode;

        if (auto_mark_days === null || auto_mark_days === undefined) {
            // Default mode - show inherited value on slider
            $default.addClass('NB-active');
            mode = 'default';
            slider_value = default_days === 0 ? 400 : default_days;
        } else if (auto_mark_days === 0) {
            // Never mode - slider at max
            $never.addClass('NB-active');
            mode = 'never';
            slider_value = 400;
        } else {
            // Days mode - show actual days
            $days.addClass('NB-active');
            mode = 'days';
            slider_value = auto_mark_days;
        }

        $slider.val(slider_value);
        this.update_slider_status_text($slider_value, mode, mode === 'days' ? auto_mark_days : default_days, default_source);
        this.update_slider_gradient($slider, slider_value);
    },

    update_slider_status_text: function ($element, mode, days, source) {
        var html = '';
        if (mode === 'default') {
            if (days === 0) {
                html = 'Using default: <b>never</b> (from ' + source + ')';
            } else {
                html = 'Using default: <b>' + days + ' day' + (days !== 1 ? 's' : '') + '</b> (from ' + source + ')';
            }
        } else if (mode === 'never') {
            html = 'Stories will <b>never</b> be marked as read';
        } else {
            html = 'Stories marked as read at <b>' + days + ' day' + (days !== 1 ? 's' : '') + '</b>';
        }
        $element.html(html);
    },

    update_slider_gradient: function ($slider, value) {
        var min = parseInt($slider.attr('min'), 10) || 1;
        var max = parseInt($slider.attr('max'), 10) || 400;
        var percent = ((value - min) / (max - min)) * 100;

        // Create gradient: blue for filled, light gray for unfilled, darker gray for "never" zone (366-400)
        var never_zone_start = ((365 - min) / (max - min)) * 100;

        if (value > 365) {
            // In never zone - all blue up to never zone, then purple for never
            $slider.css('background', 'linear-gradient(to right, #4a90d9 0%, #4a90d9 ' + never_zone_start + '%, #8b5cf6 ' + never_zone_start + '%, #8b5cf6 100%)');
        } else {
            // Normal days - blue up to value, gray for rest, purple for never zone
            $slider.css('background', 'linear-gradient(to right, #4a90d9 0%, #4a90d9 ' + percent + '%, #e0e0e0 ' + percent + '%, #e0e0e0 ' + never_zone_start + '%, #d4d0e8 ' + never_zone_start + '%, #d4d0e8 100%)');
        }
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

    open_auto_mark_read: function () {
        var is_river = _.string.contains(this.options.feed_id, 'river:');
        var folder_title = is_river ? this.options.feed_id.replace('river:', '') : null;

        this.close(_.bind(function () {
            if (is_river) {
                NEWSBLUR.reader.open_feed_exception_modal(folder_title, {
                    folder_title: folder_title,
                    scroll_to_auto_mark_read: true
                });
            } else {
                NEWSBLUR.reader.open_feed_exception_modal(this.options.feed_id, { scroll_to_auto_mark_read: true });
            }
        }, this));
    },

    open_premium_modal: function (e) {
        e.preventDefault();
        e.stopPropagation();
        this.close(_.bind(function () {
            NEWSBLUR.reader.open_premium_upgrade_modal();
        }, this));
    },

    change_auto_mark_read_setting: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.currentTarget);
        var value = $target.data('value');
        var $slider = this.$('.NB-auto-mark-read-slider');
        var $slider_value = this.$('.NB-auto-mark-read-slider-value');

        // Calculate default values for slider positioning
        var site_wide_days = NEWSBLUR.Preferences.days_of_unread || 14;
        var default_days = site_wide_days;
        var default_source = 'site-wide';

        var is_river = _.string.contains(this.options.feed_id, 'river:');
        var folder_title = is_river ? this.options.feed_id.replace('river:', '') : null;
        var feed = is_river ? null : NEWSBLUR.assets.get_feed(this.options.feed_id);

        if (!is_river && feed) {
            var folders = NEWSBLUR.assets.get_feed_folders(feed.id);
            var feed_folder_title = folders && folders.length > 0 ? folders[0] : null;
            var folder_setting = feed_folder_title ? NEWSBLUR.assets.get_folder_auto_mark_read(feed_folder_title) : null;
            if (folder_setting !== null && folder_setting !== undefined) {
                default_days = folder_setting;
                default_source = feed_folder_title;
            }
        }

        if (!NEWSBLUR.Globals.is_archive) {
            // Snap back to default and flash the upgrade notice
            if (value !== 'default') {
                this.$('.NB-auto-mark-read-option').removeClass('NB-active');
                this.$('.NB-auto-mark-read-default').addClass('NB-active');
                this.flash_upgrade_notice();
            }
            return;
        }

        if (!feed && !is_river) return;

        // Update UI immediately
        this.$('.NB-auto-mark-read-option').removeClass('NB-active');
        $target.addClass('NB-active');

        var days = null;
        var slider_value;

        if (value === 'default') {
            days = null;
            slider_value = default_days === 0 ? 400 : default_days;
            this.update_slider_status_text($slider_value, 'default', default_days, default_source);
        } else if (value === 'never') {
            days = 0;
            slider_value = 400;
            this.update_slider_status_text($slider_value, 'never', 0, default_source);
        } else if (value === 'days') {
            var current_slider = parseInt($slider.val(), 10);
            // If slider is in never zone, default to 30 days
            days = current_slider > 365 ? 30 : current_slider;
            slider_value = days;
            this.update_slider_status_text($slider_value, 'days', days, default_source);
        }

        $slider.val(slider_value);
        this.update_slider_gradient($slider, slider_value);

        if (is_river) {
            this.save_folder_auto_mark_read(folder_title, days);
        } else {
            this.save_auto_mark_read(feed, days);
        }
    },

    on_auto_mark_read_slider_input: function (e) {
        var $slider = $(e.currentTarget);
        var slider_val = parseInt($slider.val(), 10);
        var $slider_value = this.$('.NB-auto-mark-read-slider-value');

        // Determine if we're in the "never" zone (366+)
        var is_never = slider_val > 365;
        var days = is_never ? 0 : slider_val;

        // Update gradient
        this.update_slider_gradient($slider, slider_val);

        // Calculate default source for status text
        var site_wide_days = NEWSBLUR.Preferences.days_of_unread || 14;
        var default_source = 'site-wide';

        if (!NEWSBLUR.Globals.is_archive) {
            // Let them see the slider move but snap back after a moment
            if (this._slider_snap_timer) {
                clearTimeout(this._slider_snap_timer);
            }
            this._slider_snap_timer = setTimeout(_.bind(function () {
                var default_days = site_wide_days;
                var snap_val = default_days === 0 ? 400 : default_days;
                $slider.val(snap_val);
                this.update_slider_status_text($slider_value, 'default', default_days, default_source);
                this.update_slider_gradient($slider, snap_val);
                this.$('.NB-auto-mark-read-option').removeClass('NB-active');
                this.$('.NB-auto-mark-read-default').addClass('NB-active');
                this.flash_upgrade_notice();
            }, this), 150);
            // Still update text while dragging
            if (is_never) {
                this.update_slider_status_text($slider_value, 'never', 0, default_source);
            } else {
                this.update_slider_status_text($slider_value, 'days', slider_val, default_source);
            }
            return;
        }

        var is_river = _.string.contains(this.options.feed_id, 'river:');
        var folder_title = is_river ? this.options.feed_id.replace('river:', '') : null;
        var feed = is_river ? null : NEWSBLUR.assets.get_feed(this.options.feed_id);

        // Auto-select appropriate option based on slider position
        this.$('.NB-auto-mark-read-option').removeClass('NB-active');
        if (is_never) {
            this.$('.NB-auto-mark-read-never').addClass('NB-active');
            this.update_slider_status_text($slider_value, 'never', 0, default_source);
        } else {
            this.$('.NB-auto-mark-read-days').addClass('NB-active');
            this.update_slider_status_text($slider_value, 'days', slider_val, default_source);
        }

        // Debounce the save
        if (this._auto_mark_read_timer) {
            clearTimeout(this._auto_mark_read_timer);
        }
        this._auto_mark_read_timer = setTimeout(_.bind(function () {
            if (is_river) {
                this.save_folder_auto_mark_read(folder_title, days);
            } else {
                this.save_auto_mark_read(feed, days);
            }
        }, this), 300);
    },

    update_clustering_ui: function () {
        var clustering_enabled = NEWSBLUR.assets.preference('story_clustering');
        var cluster_mark_read = NEWSBLUR.assets.preference('cluster_mark_read');

        // Default to true for archive users, false for non-archive
        if (clustering_enabled === undefined || clustering_enabled === null) {
            clustering_enabled = NEWSBLUR.Globals.is_archive;
        }
        if (cluster_mark_read === undefined || cluster_mark_read === null) {
            cluster_mark_read = false;
        }

        this.$('.NB-clustering-enabled-on').toggleClass('NB-active', !!clustering_enabled);
        this.$('.NB-clustering-enabled-off').toggleClass('NB-active', !clustering_enabled);
        this.$('.NB-clustering-read-on').toggleClass('NB-active', !!cluster_mark_read);
        this.$('.NB-clustering-read-off').toggleClass('NB-active', !cluster_mark_read);

        // Fade the mark-read section when clustering is disabled
        this.$('.NB-clustering-read-section').toggleClass('NB-disabled', !clustering_enabled);
    },

    change_clustering_setting: function (e) {
        e.preventDefault();
        e.stopPropagation();

        var $target = $(e.currentTarget);
        var setting = $target.data('setting');
        var value = $target.data('value');

        if (!NEWSBLUR.Globals.is_archive) {
            this.flash_clustering_upgrade_notice();
            return;
        }

        var bool_value = value === 'true' || value === true;
        NEWSBLUR.assets.preference(setting, bool_value);

        // Update UI
        this.update_clustering_ui();

        // Reload feed to apply clustering changes
        if (setting === 'story_clustering') {
            this.reload_feed();
        }
    },

    flash_clustering_upgrade_notice: function () {
        var $notice = this.$('.NB-clustering-upgrade-notice');
        $notice.addClass('NB-flash');
        setTimeout(function () {
            $notice.removeClass('NB-flash');
        }, 600);
    },

    flash_upgrade_notice: function () {
        var $notice = this.$('.NB-auto-mark-read-upgrade-notice');
        $notice.addClass('NB-flash');
        setTimeout(function () {
            $notice.removeClass('NB-flash');
        }, 600);
    },

    flash_date_filter_upgrade_notice: function () {
        var $notice = this.$('.NB-date-filter-upgrade-notice');
        $notice.addClass('NB-flash');
        setTimeout(function () {
            $notice.removeClass('NB-flash');
        }, 600);
    },

    save_auto_mark_read: function (feed, days) {
        NEWSBLUR.assets.save_feed_auto_mark_read(feed.id, days, function () {
            feed.set('auto_mark_read_days', days);
            // Refresh feed to recalculate unread counts, then reload feed after refresh completes
            NEWSBLUR.reader.force_feeds_refresh(function () {
                NEWSBLUR.reader.reload_feed();
            }, false, feed.id);
        });
    },

    save_folder_auto_mark_read: function (folder_title, days) {
        NEWSBLUR.assets.save_folder_auto_mark_read(folder_title, days, function () {
            // Refresh all feeds in the folder to update unread counts, then reload
            var folder = NEWSBLUR.assets.get_folder(folder_title);
            if (folder) {
                var feed_ids = folder.feed_ids_in_folder();
                NEWSBLUR.reader.force_feeds_refresh(function () {
                    NEWSBLUR.reader.reload_feed();
                }, false, feed_ids);
            } else {
                NEWSBLUR.reader.reload_feed();
            }
        });
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
        if (!NEWSBLUR.Globals.is_archive) {
            this.$('.NB-date-start').val('');
            this.$('.NB-date-end').val('');
            this.flash_date_filter_upgrade_notice();
            return;
        }

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
        if (!NEWSBLUR.Globals.is_archive) {
            this.flash_date_filter_upgrade_notice();
            return;
        }

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

        if (!NEWSBLUR.Globals.is_archive) {
            this.$('.NB-date-start').val('');
            this.$('.NB-date-end').val('');
            this.flash_date_filter_upgrade_notice();
            return;
        }

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
