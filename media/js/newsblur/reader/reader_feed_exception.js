NEWSBLUR.ReaderFeedException = function (feed_id, options) {
    var defaults = {
        'onOpen': function () {
            $(window).trigger('resize.simplemodal');
        },
        'width': 700
    };

    this.options = $.extend({}, defaults, options);
    this.model = NEWSBLUR.assets;
    this.feed_id = _.isString(feed_id) && _.string.startsWith(feed_id, 'feed:') ? parseInt(feed_id.replace('feed:', ''), 10) : feed_id;
    this.feed = this.model.get_feed(feed_id);
    this.folder_title = this.options.folder_title;
    this.folder = this.folder_title && NEWSBLUR.assets.get_folder(this.folder_title);

    this.runner();
};

NEWSBLUR.ReaderFeedException.prototype = new NEWSBLUR.Modal;
NEWSBLUR.ReaderFeedException.prototype.constructor = NEWSBLUR.ReaderFeedException;

_.extend(NEWSBLUR.ReaderFeedException.prototype, {

    runner: function () {
        if (this.folder) {
            NEWSBLUR.Modal.prototype.initialize_folder.call(this, this.folder_title);
        } else {
            NEWSBLUR.Modal.prototype.initialize_feed.call(this, this.feed_id);
        }
        this.make_modal();
        if (this.folder) {
            this.setup_folder_tabs();
        }
        if (this.feed) {
            this.setup_feed_tabs();
            this.show_recommended_options_meta();
            _.delay(_.bind(function () {
                this.get_feed_settings();
            }, this), 50);
        }
        this.handle_cancel();
        this.open_modal();
        this.initialize_feed(this.feed_id);

        this.$modal.bind('click', $.rescope(this.handle_click, this));
        this.$modal.bind('change', $.rescope(this.handle_change, this));
        this.$modal.bind('input', $.rescope(this.handle_input, this));

        if (this.options.scroll_to_auto_mark_read) {
            _.delay(_.bind(function () {
                var $auto_mark_read = $('.NB-exception-option-auto-mark-read', this.$modal);
                if ($auto_mark_read.length) {
                    $auto_mark_read[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
                    $auto_mark_read.addClass('NB-highlighted');
                    _.delay(function () {
                        $auto_mark_read.removeClass('NB-highlighted');
                    }, 2000);
                }
            }, this), 100);
        }
    },

    initialize_feed: function (feed_id) {
        var view_setting = this.model.view_setting(feed_id, 'view');
        var story_layout = this.model.view_setting(feed_id, 'layout');

        if (this.feed) {
            NEWSBLUR.Modal.prototype.initialize_feed.call(this, feed_id);
            $('input[name=feed_link]', this.$modal).val(this.feed.get('feed_link'));
            $('input[name=feed_address]', this.$modal).val(this.feed.get('feed_address'));
            $(".NB-exception-option-page", this.$modal).toggle(this.feed.is_feed() || this.feed.is_social());
            $(".NB-view-setting-original", this.$modal).toggle(this.feed.is_feed() || this.feed.is_social());
        } else if (this.folder) {
            NEWSBLUR.Modal.prototype.initialize_folder.call(this, this.folder_title);
        }

        // Set active state on segmented controls
        $('.NB-view-setting-option', this.$modal).removeClass('NB-active');
        $('.NB-view-setting-option[data-value="' + view_setting + '"]', this.$modal).addClass('NB-active');
        $('.NB-layout-setting-option', this.$modal).removeClass('NB-active');
        $('.NB-layout-setting-option[data-value="' + story_layout + '"]', this.$modal).addClass('NB-active');

        if (this.folder) {
            this.$modal.addClass('NB-modal-folder-settings');
            this.$modal.removeClass('NB-modal-feed-settings');
            $(".NB-modal-title", this.$modal).text("Folder Settings");
        } else if (this.feed && this.feed.get('exception_type')) {
            this.$modal.removeClass('NB-modal-folder-settings');
            this.$modal.removeClass('NB-modal-feed-settings');
            $(".NB-modal-title", this.$modal).text("Fix a misbehaving site");
        } else if (this.feed) {
            this.$modal.removeClass('NB-modal-folder-settings');
            this.$modal.addClass('NB-modal-feed-settings');
            $(".NB-modal-title", this.$modal).text("Site Settings");
        }

        this.resize();
    },

    get_feed_settings: function () {
        if (this.feed.is_starred()) return;

        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');

        var settings_fn = this.options.social_feed ? this.model.get_social_settings :
            this.model.get_feed_settings;
        settings_fn.call(this.model, this.feed_id, _.bind(this.populate_settings, this));
    },

    populate_settings: function (data) {
        var $submit = $('.NB-modal-submit-save', this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);
        var $page_history = $(".NB-exception-page-history", this.$modal);
        var $feed_history = $(".NB-exception-feed-history", this.$modal);

        $feed_history.html(this.make_history(data, 'feed_fetch'));
        $page_history.html(this.make_history(data, 'page_fetch'));

        $loading.removeClass('NB-active');
        this.resize();
    },

    make_modal: function () {
        var self = this;

        this.$modal = $.make('div', { className: 'NB-modal-exception NB-modal' }, [
            (this.feed && $.make('div', { className: 'NB-modal-feed-chooser-container' }, [
                this.make_feed_chooser()
            ])),
            $.make('div', { className: 'NB-modal-loading' }),
            $.make('h2', { className: 'NB-modal-title NB-exception-block-only' }, 'Fix a misbehaving site'),
            $.make('h2', { className: 'NB-modal-title' }, 'Site settings'),
            $.make('h2', { className: 'NB-modal-subtitle' }, [
                $.make('img', { className: 'NB-modal-feed-image feed_favicon' }),
                $.make('div', { className: 'NB-modal-feed-heading' }, [
                    $.make('span', { className: 'NB-modal-feed-title' }),
                    $.make('span', { className: 'NB-modal-feed-subscribers' }),
                    $.make('a', { className: 'NB-folder-icon-clear-header', href: '#', style: 'display: none' }, 'Clear icon')
                ])
            ]),
            (this.folder && $.make('div', { className: 'NB-modal-tabs' }, [
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-settings' }, 'Settings'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-folder-icon' }, 'Folder Icon')
            ])),
            (this.feed && !this.feed.is_starred() && !this.feed.is_social() && $.make('div', { className: 'NB-modal-tabs NB-modal-tabs-feed' }, [
                $.make('div', { className: 'NB-modal-tab NB-active NB-modal-tab-settings' }, 'Settings'),
                $.make('div', { className: 'NB-modal-tab NB-modal-tab-feed-icon' }, 'Feed Icon')
            ])),
            $.make('div', { className: 'NB-tab NB-tab-settings NB-active' }),
            $.make('div', { className: 'NB-tab NB-tab-folder-icon' }),
            $.make('div', { className: 'NB-tab NB-tab-feed-icon' }),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-view NB-modal-submit NB-settings-only' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-status NB-right' }),
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    'View settings'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    // Reading view row
                    $.make('div', { className: 'NB-view-setting-row' }, [
                        $.make('div', { className: 'NB-view-setting-label' }, 'Reading view'),
                        $.make('ul', { className: 'segmented-control NB-view-setting-control' }, [
                            $.make('li', { className: 'NB-view-setting-option NB-view-setting-original', 'data-value': 'page' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/content-view-original.svg' }),
                                $.make('span', 'Original')
                            ]),
                            $.make('li', { className: 'NB-view-setting-option', 'data-value': 'feed' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/content-view-feed.svg' }),
                                $.make('span', 'Feed')
                            ]),
                            $.make('li', { className: 'NB-view-setting-option', 'data-value': 'text' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/content-view-text.svg' }),
                                $.make('span', 'Text')
                            ]),
                            $.make('li', { className: 'NB-view-setting-option', 'data-value': 'story' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/content-view-story.svg' }),
                                $.make('span', 'Story')
                            ])
                        ])
                    ]),
                    // Story layout row
                    $.make('div', { className: 'NB-view-setting-row' }, [
                        $.make('div', { className: 'NB-view-setting-label' }, 'Story layout'),
                        $.make('ul', { className: 'segmented-control NB-layout-setting-control' }, [
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'full' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-full.svg' }),
                                $.make('span', 'Full')
                            ]),
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'split' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-split.svg' }),
                                $.make('span', 'Split')
                            ]),
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'list' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-list.svg' }),
                                $.make('span', 'List')
                            ]),
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'grid' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-grid.svg' }),
                                $.make('span', 'Grid')
                            ]),
                            $.make('li', { className: 'NB-layout-setting-option', 'data-value': 'magazine' }, [
                                $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/layout-magazine.svg' }),
                                $.make('span', 'Magazine')
                            ])
                        ])
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-auto-mark-read NB-modal-submit NB-settings-only' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-status' }),
                    'Auto Mark as Read',
                    (!NEWSBLUR.Globals.is_archive && $.make('a', { className: 'NB-auto-mark-read-upgrade-notice NB-premium-link', href: '#' }, [
                        $.make('span', { className: 'NB-archive-badge' }, 'Premium Archive')
                    ]))
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('ul', { className: 'segmented-control NB-menu-manage-auto-mark-read' }, [
                        $.make('li', { className: 'NB-auto-mark-read-option NB-auto-mark-read-default', 'data-value': 'default', role: 'button' }, 'Default'),
                        $.make('li', { className: 'NB-auto-mark-read-option NB-auto-mark-read-days', 'data-value': 'days', role: 'button' }, 'Days'),
                        $.make('li', { className: 'NB-auto-mark-read-option NB-auto-mark-read-never', 'data-value': 'never', role: 'button' }, 'Never')
                    ]),
                    $.make('div', { className: 'NB-auto-mark-read-slider-container' }, [
                        $.make('input', {
                            type: 'range',
                            className: 'NB-auto-mark-read-slider',
                            name: 'auto_mark_read_days',
                            min: '1',
                            max: '400',
                            value: '14'
                        }),
                        $.make('div', { className: 'NB-auto-mark-read-slider-value' })
                    ])
                ])
            ]),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-retry NB-modal-submit NB-exception-block-only' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 1:'),
                    'Retry'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-retry' }, 'Retry fetching and parsing'),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ]),
            (this.feed && $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-feed NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 2:'),
                    'Change RSS Feed Address'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-address', className: 'NB-exception-label' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'RSS/XML URL: '
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-address', className: 'NB-exception-input-address NB-input', name: 'feed_address', value: this.feed.get('feed_address') })
                    ]),
                    (this.feed.is_feed() && $.make('div', { className: 'NB-exception-submit-wrapper' }, [
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-address' }, 'Parse this RSS/XML Feed'),
                        $.make('div', { className: 'NB-error' }),
                        $.make('div', { className: 'NB-exception-feed-history' })
                    ]))
                ])
            ])),
            (this.feed && $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-page NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 3:'),
                    'Change Website Address'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-link', className: 'NB-exception-label' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'Website URL: '
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-link', className: 'NB-exception-input-link NB-input', name: 'feed_link', value: this.feed.get('feed_link') })
                    ]),
                    (this.feed.is_feed() && $.make('div', { className: 'NB-exception-submit-wrapper' }, [
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-green NB-modal-submit-link' }, 'Fetch Feed From Website'),
                        $.make('div', { className: 'NB-error' }),
                        $.make('div', { className: 'NB-exception-page-history' })
                    ]))
                ])
            ])),
            (this.folder && $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-feed NB-modal-submit' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    'Folder RSS Feed Address'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-folder-rss-row' }, [
                        $.make('div', { className: 'NB-folder-rss-label' }, 'Unread+Focus:'),
                        $.make('div', { className: 'NB-folder-rss-wrapper' }, [
                            $.make('input', {
                                type: 'text',
                                id: 'NB-folder-rss-unread',
                                className: 'NB-input NB-folder-rss-input',
                                name: 'folder_rss_unread_url',
                                value: this.folder.rss_url('unread'),
                                readonly: 'readonly'
                            }),
                            $.make('div', { className: 'NB-folder-rss-copy NB-modal-submit-button NB-modal-submit-grey', 'data-url-type': 'unread' }, 'Copy')
                        ])
                    ]),
                    $.make('div', { className: 'NB-folder-rss-row' }, [
                        $.make('div', { className: 'NB-folder-rss-label' }, 'Only Focus:'),
                        $.make('div', { className: 'NB-folder-rss-wrapper' }, [
                            $.make('input', {
                                type: 'text',
                                id: 'NB-folder-rss-focus',
                                className: 'NB-input NB-folder-rss-input',
                                name: 'folder_rss_focus_url',
                                value: this.folder.rss_url('focus'),
                                readonly: 'readonly'
                            }),
                            $.make('div', { className: 'NB-folder-rss-copy NB-modal-submit-button NB-modal-submit-grey', 'data-url-type': 'focus' }, 'Copy')
                        ])
                    ]),
                    (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-premium-only' }, [
                        $.make('div', { className: 'NB-premium-only-text' }, [
                            'RSS feeds for folders is a ',
                            $.make('a', { href: '#', className: 'NB-premium-only-link NB-splash-link' }, 'premium feature'),
                            '.'
                        ])
                    ]))
                ])
            ])),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-delete NB-exception-block-only NB-modal-submit' }, [
                $.make('h5', [
                    $.make('span', { className: 'NB-exception-option-option NB-exception-only' }, 'Option 4:'),
                    'Just Delete This Feed'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('div', { className: 'NB-modal-submit-button NB-modal-submit-red NB-modal-submit-delete' }, 'Delete It. It Just Won\'t Work!'),
                        $.make('div', { className: 'NB-error' })
                    ])
                ])
            ])
        ]);
    },

    make_history: function (data, fetch_type) {
        var fetches = data[fetch_type + '_history'];
        var $history;

        if (fetches && fetches.length) {
            $history = _.map(fetches, function (fetch) {
                var feed_ok = _.contains([200, 304], fetch.status_code) || !fetch.status_code;
                var status_class = feed_ok ? ' NB-ok ' : ' NB-errorcode ';
                return $.make('div', { className: 'NB-history-fetch' + status_class, title: feed_ok ? '' : fetch.exception }, [
                    $.make('div', { className: 'NB-history-fetch-date' }, fetch.fetch_date || fetch.push_date),
                    $.make('div', { className: 'NB-history-fetch-message' }, [
                        fetch.message,
                        (fetch.status_code && $.make('div', { className: 'NB-history-fetch-code' }, ' (' + fetch.status_code + ')'))
                    ])
                ]);
            });
        }

        return $.make('div', $history);
    },

    show_recommended_options_meta: function () {
        var $meta_retry = $('.NB-exception-option-retry .NB-exception-option-meta', this.$modal);
        var $meta_page = $('.NB-exception-option-page .NB-exception-option-meta', this.$modal);
        var $meta_feed = $('.NB-exception-option-feed .NB-exception-option-meta', this.$modal);
        var is_400 = (400 <= this.feed.get('exception_code') && this.feed.get('exception_code') < 500);

        if (!is_400) {
            $meta_retry.addClass('NB-exception-option-meta-recommended');
            $meta_retry.text('Recommended');
            return;
        }
        if (this.feed.get('exception_type') == 'feed') {
            $meta_page.addClass('NB-exception-option-meta-recommended');
            $meta_page.text('Recommended');
        }
        if (this.feed.get('exception_type') == 'page') {
            if (is_400) {
                $meta_feed.addClass('NB-exception-option-meta-recommended');
                $meta_feed.text('Recommended');
            } else {
                $meta_page.addClass('NB-exception-option-meta-recommended');
                $meta_page.text('Recommended');
            }
        }
    },

    handle_cancel: function () {
        var $cancel = $('.NB-modal-cancel', this.$modal);

        $cancel.click(function (e) {
            e.preventDefault();
            $.modal.close();
        });
    },

    save_retry_feed: function () {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');
        var feed_id = this.feed_id;

        $('.NB-modal-submit-retry', this.$modal).addClass('NB-disabled').attr('value', 'Fetching...');

        this.model.save_exception_retry(feed_id, function () {
            NEWSBLUR.reader.force_feed_refresh(feed_id);
            $.modal.close();
        });
    },

    delete_feed: function () {
        var $loading = $('.NB-modal-loading', this.$modal);
        $loading.addClass('NB-active');

        $('.NB-modal-submit-delete', this.$modal).addClass('NB-disabled').attr('value', 'Deleting...');

        var feed_id = this.feed_id;

        // this.model.delete_feed(feed_id, function() {
        NEWSBLUR.reader.manage_menu_delete_feed(feed_id);
        _.delay(function () { $.modal.close(); }, 500);
        // });
    },

    change_feed_address: function () {
        var feed_id = this.feed_id;
        var $loading = $('.NB-modal-loading', this.$modal);
        var $feed_address = $('input[name=feed_address]', this.$modal);
        var $submit = $('.NB-modal-submit-address', this.$modal);
        var $error = $feed_address.closest('.NB-exception-option').find('.NB-error');
        var feed_address = $feed_address.val();

        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').attr('value', 'Parsing...');
        $error.hide().html('');

        if (feed_address.length) {
            this.model.save_exception_change_feed_address(feed_id, feed_address, _.bind(function (data) {
                console.log(["return to change address", data]);
                NEWSBLUR.assets.feeds.add(_.values(data.feeds));
                var feed = NEWSBLUR.assets.get_feed(data.new_feed_id || feed_id);
                var old_feed = NEWSBLUR.assets.get_feed(feed_id);
                if (data.new_feed_id != feed_id && old_feed.get('selected')) {
                    old_feed.set('selected', false);
                }

                if (data && data.new_feed_id) {
                    NEWSBLUR.assets.load_feeds(function () {
                        var feed = NEWSBLUR.assets.get_feed(data.new_feed_id || feed_id);
                        console.log(["Loading feed", data.new_feed_id || feed_id, feed]);
                        NEWSBLUR.reader.open_feed(feed.id);
                    });
                }

                console.log(["feed address", feed, NEWSBLUR.assets.get_feed(feed_id)]);
                if (!data || data.code < 0 || !data.new_feed_id) {
                    var error = data.message || "There was a problem fetching the feed from this URL.";
                    if (parseInt(feed.get('exception_code'), 10) == 404) {
                        error = "URL gives a 404 - page not found.";
                    }
                    $error.show().html((data && data.message) || error);
                }
                $loading.removeClass('NB-active');
                $submit.removeClass('NB-disabled').attr('value', 'Parse this RSS/XML Feed');
                this.populate_settings(data);
            }, this));
        }
    },

    change_feed_link: function () {
        var feed_id = this.feed_id;
        var $feed_link = $('input[name=feed_link]', this.$modal);
        var $loading = $('.NB-modal-loading', this.$modal);
        var $submit = $('.NB-modal-submit-link', this.$modal);
        var $error = $feed_link.closest('.NB-exception-option').find('.NB-error');
        var feed_link = $feed_link.val();

        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').attr('value', 'Fetching...');
        $error.hide().html('');

        if (feed_link.length) {
            this.model.save_exception_change_feed_link(feed_id, feed_link, _.bind(function (data) {
                var old_feed = NEWSBLUR.assets.get_feed(feed_id);
                if (data.new_feed_id != feed_id && old_feed.get('selected')) {
                    old_feed.set('selected', false);
                }

                if (data && data.new_feed_id) {
                    NEWSBLUR.assets.load_feeds(function () {
                        var feed = NEWSBLUR.assets.get_feed(data.new_feed_id || feed_id);
                        console.log(["Loading feed", data.new_feed_id || feed_id, feed]);
                        NEWSBLUR.reader.open_feed(feed.id);
                    });
                }

                var feed = NEWSBLUR.assets.get_feed(data.new_feed_id) || NEWSBLUR.assets.get_feed(feed_id);

                if (!data || data.code < 0 || !data.new_feed_id) {
                    var error = data.message || "There was a problem fetching the feed from this URL.";
                    if (feed.get('exception_code') == '404') {
                        error = "URL gives a 404 - page not found.";
                    }
                    $error.show().html((data && data.message) || error);
                }
                $loading.removeClass('NB-active');
                $submit.removeClass('NB-disabled').attr('value', 'Fetch Feed from Website');
                this.populate_settings(data);
            }, this));
        }
    },

    // ===========
    // = Actions =
    // ===========

    handle_click: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-view-setting-option' }, function ($t, $p) {
            e.preventDefault();
            var value = $t.data('value');
            $('.NB-view-setting-option', self.$modal).removeClass('NB-active');
            $t.addClass('NB-active');
            if (self.folder) {
                self.folder.view_setting({ 'view': value });
            } else {
                NEWSBLUR.assets.view_setting(self.feed_id, { 'view': value });
            }
            self.animate_saved();
        });
        $.targetIs(e, { tagSelector: '.NB-layout-setting-option' }, function ($t, $p) {
            e.preventDefault();
            var value = $t.data('value');
            $('.NB-layout-setting-option', self.$modal).removeClass('NB-active');
            $t.addClass('NB-active');
            if (self.folder) {
                self.folder.view_setting({ 'layout': value });
            } else {
                NEWSBLUR.assets.view_setting(self.feed_id, { 'layout': value });
            }
            self.animate_saved();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-retry' }, function ($t, $p) {
            e.preventDefault();

            self.save_retry_feed();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-delete' }, function ($t, $p) {
            e.preventDefault();

            self.delete_feed();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-address' }, function ($t, $p) {
            e.preventDefault();

            self.change_feed_address();
        });
        $.targetIs(e, { tagSelector: '.NB-modal-submit-link' }, function ($t, $p) {
            e.preventDefault();

            self.change_feed_link();
        });
        $.targetIs(e, { tagSelector: '.NB-premium-only-link' }, function ($t, $p) {
            e.preventDefault();

            self.close(function () {
                NEWSBLUR.reader.open_premium_upgrade_modal();
            });
        });
        $.targetIs(e, { tagSelector: '.NB-premium-archive-link' }, function ($t, $p) {
            e.preventDefault();

            self.close(function () {
                NEWSBLUR.reader.open_premium_upgrade_modal();
            });
        });
        $.targetIs(e, { tagSelector: '.NB-auto-mark-read-upgrade-notice' }, function ($t, $p) {
            e.preventDefault();

            self.close(function () {
                NEWSBLUR.reader.open_premium_upgrade_modal();
            });
        });
        $.targetIs(e, { tagSelector: '.NB-auto-mark-read-option' }, function ($t, $p) {
            e.preventDefault();
            self.handle_auto_mark_read_option_click($t);
        });
        $.targetIs(e, { tagSelector: '.NB-folder-rss-copy' }, function ($t, $p) {
            e.preventDefault();
            var url_type = $t.data('url-type');
            self.copy_folder_rss_url(url_type, $t);
        });
        // Tab handlers (work for both folder and feed)
        $.targetIs(e, { tagSelector: '.NB-modal-tab-settings' }, function ($t, $p) {
            e.preventDefault();
            self.switch_tab('settings');
        });
        $.targetIs(e, { tagSelector: '.NB-modal-tab-folder-icon' }, function ($t, $p) {
            e.preventDefault();
            self.switch_tab('folder-icon');
        });
        $.targetIs(e, { tagSelector: '.NB-modal-tab-feed-icon' }, function ($t, $p) {
            e.preventDefault();
            self.switch_tab('feed-icon');
        });
        // Icon selection handlers (work for both folder and feed)
        $.targetIs(e, { tagSelector: '.NB-folder-icon-preset' }, function ($t, $p) {
            e.preventDefault();
            var icon_name = $t.data('icon');
            var icon_set = $t.data('icon-set') || 'lucide';
            self.select_preset_icon(icon_name, icon_set);
        });
        $.targetIs(e, { tagSelector: '.NB-folder-icon-emoji-option' }, function ($t, $p) {
            e.preventDefault();
            var emoji = $t.data('emoji');
            self.select_emoji_icon(emoji);
        });
        $.targetIs(e, { tagSelector: '.NB-folder-icon-color' }, function ($t, $p) {
            e.preventDefault();
            var color = $t.data('color');
            self.select_icon_color(color);
        });
        $.targetIs(e, { tagSelector: '.NB-folder-icon-upload-button' }, function ($t, $p) {
            e.preventDefault();
            $('.NB-folder-icon-file-input', self.$modal).click();
        });
        $.targetIs(e, { tagSelector: '.NB-folder-icon-clear' }, function ($t, $p) {
            e.preventDefault();
            if (self.folder) {
                self.clear_folder_icon();
            } else if (self.feed) {
                self.clear_feed_icon();
            }
        });
    },

    animate_saved: function () {
        var $status = $('.NB-exception-option-view .NB-exception-option-status', this.$modal);
        $status.text('Saved').animate({
            'opacity': 1
        }, {
            'queue': false,
            'duration': 600,
            'complete': function () {
                _.delay(function () {
                    $status.animate({ 'opacity': 0 }, { 'queue': false, 'duration': 1000 });
                }, 300);
            }
        });
    },

    copy_folder_rss_url: function (url_type, $button) {
        var input_id = url_type === 'unread' ? '#NB-folder-rss-unread' : '#NB-folder-rss-focus';
        var $input = $(input_id, this.$modal);

        $input[0].select();
        document.execCommand('copy');

        $button.text('Copied!');
        _.delay(function () {
            $button.text('Copy');
        }, 1500);
    },

    setup_folder_tabs: function () {
        var self = this;
        var $settings_tab = $('.NB-tab-settings', this.$modal);
        var $folder_icon_tab = $('.NB-tab-folder-icon', this.$modal);

        // Move folder-specific content into the Settings tab
        var $view_settings = $('.NB-exception-option-view', this.$modal).detach();
        var $auto_mark_read = $('.NB-exception-option-auto-mark-read', this.$modal).detach();
        var $folder_rss = $('.NB-exception-option-feed', this.$modal).detach();
        $settings_tab.append($view_settings).append($auto_mark_read).append($folder_rss);

        // Initialize auto-mark-read settings
        this.setup_auto_mark_read_for_folder();

        // Build folder icon tab content
        this.folder_icon = NEWSBLUR.assets.get_folder_icon(this.folder_title) || {};
        this.selected_icon_type = this.folder_icon.icon_type || 'none';
        this.selected_icon_data = this.folder_icon.icon_data || '';
        this.selected_icon_color = this.folder_icon.icon_color || '#000000';

        $folder_icon_tab.append(this.make_folder_icon_tab());

        // Update header icon to show custom icon if one exists
        if (this.folder_icon && this.folder_icon.icon_type && this.folder_icon.icon_type !== 'none') {
            this.update_header_icon();
        }
        this.select_current_icon();
        this.select_current_color();
        // Apply color preview to icon grid if color is set
        if (this.selected_icon_color && this.selected_icon_color !== '#000000') {
            this.update_icon_grid_colors(this.selected_icon_color);
        }

        // Show/hide header clear link based on whether there's an icon
        var has_icon = !!(this.folder_icon && this.folder_icon.icon_type && this.folder_icon.icon_type !== 'none');
        $('.NB-folder-icon-clear-header', this.$modal).toggle(has_icon);

        // Add click handler for header clear link
        $('.NB-folder-icon-clear-header', this.$modal).on('click', function (e) {
            e.preventDefault();
            self.clear_folder_icon();
        });

        // Add change handler for file input
        $('.NB-folder-icon-file-input', this.$modal).on('change', _.bind(this.handle_icon_upload, this));
    },

    make_folder_icon_tab: function () {
        // Use shared icon picker component
        return NEWSBLUR.IconPicker.make_icon_editor({
            include_upload: true,
            include_reset: false
        });
    },

    setup_feed_tabs: function () {
        var self = this;
        var $settings_tab = $('.NB-tab-settings', this.$modal);
        var $feed_icon_tab = $('.NB-tab-feed-icon', this.$modal);

        // Move all feed-specific content into the Settings tab in correct order
        var $view_settings = $('.NB-exception-option-view', this.$modal).detach();
        var $auto_mark_read = $('.NB-exception-option-auto-mark-read', this.$modal).detach();
        var $retry_option = $('.NB-exception-option-retry', this.$modal).detach();
        var $feed_option = $('.NB-exception-option-feed', this.$modal).detach();
        var $page_option = $('.NB-exception-option-page', this.$modal).detach();
        var $delete_option = $('.NB-exception-option-delete', this.$modal).detach();
        // Order: view settings, auto-mark-read, then Option 1 (retry), Option 2 (feed), Option 3 (page), Option 4 (delete)
        $settings_tab.append($view_settings).append($auto_mark_read).append($retry_option).append($feed_option).append($page_option).append($delete_option);

        // Initialize auto-mark-read settings for feed
        this.setup_auto_mark_read_for_feed();

        // Skip icon tab setup for starred/saved story tags and social/shared feeds
        if (this.feed.is_starred() || this.feed.is_social()) return;

        // Build feed icon tab content
        this.feed_icon = NEWSBLUR.assets.get_feed_icon(this.feed_id) || {};
        this.selected_icon_type = this.feed_icon.icon_type || 'none';
        this.selected_icon_data = this.feed_icon.icon_data || '';
        this.selected_icon_color = this.feed_icon.icon_color || '#000000';

        $feed_icon_tab.append(this.make_feed_icon_tab());

        // Update header icon to show custom icon if one exists
        if (this.feed_icon && this.feed_icon.icon_type && this.feed_icon.icon_type !== 'none') {
            this.update_header_icon();
        }
        this.select_current_icon();
        this.select_current_color();
        // Apply color preview to icon grid if color is set
        if (this.selected_icon_color && this.selected_icon_color !== '#000000') {
            this.update_icon_grid_colors(this.selected_icon_color);
        }

        // Show/hide header clear link based on whether there's an icon
        var has_icon = !!(this.feed_icon && this.feed_icon.icon_type && this.feed_icon.icon_type !== 'none');
        $('.NB-folder-icon-clear-header', this.$modal).toggle(has_icon);

        // Update header clear link text for feeds
        $('.NB-folder-icon-clear-header', this.$modal).text('Reset to favicon');

        // Add click handler for header clear link
        $('.NB-folder-icon-clear-header', this.$modal).on('click', function (e) {
            e.preventDefault();
            self.clear_feed_icon();
        });

        // Add change handler for file input
        $('.NB-folder-icon-file-input', this.$modal).on('change', _.bind(this.handle_icon_upload, this));
    },

    make_feed_icon_tab: function () {
        // Use shared icon picker component
        return NEWSBLUR.IconPicker.make_icon_editor({
            include_upload: true,
            include_reset: false
        });
    },

    select_current_icon: function () {
        // Always clear upload preview first
        var $preview = $('.NB-folder-icon-upload-preview', this.$modal);
        $preview.empty().removeClass('NB-active');

        var icon = this.folder ? this.folder_icon : this.feed_icon;
        if (!icon || !icon.icon_type || icon.icon_type === 'none') return;

        if (icon.icon_type === 'preset') {
            var icon_set = icon.icon_set || 'lucide';
            if (icon_set === 'heroicons-solid') {
                $('.NB-folder-icon-preset[data-icon="' + icon.icon_data + '"][data-icon-set="heroicons-solid"]', this.$modal).addClass('NB-active');
            } else {
                $('.NB-folder-icon-preset[data-icon="' + icon.icon_data + '"]:not([data-icon-set])', this.$modal).addClass('NB-active');
            }
        } else if (icon.icon_type === 'emoji') {
            var icon_data = icon.icon_data;
            $('.NB-folder-icon-emoji-option', this.$modal).each(function () {
                if ($(this).data('emoji') === icon_data) {
                    $(this).addClass('NB-active');
                }
            });
        } else if (icon.icon_type === 'upload') {
            $preview.empty().append(
                $.make('img', { src: 'data:image/png;base64,' + icon.icon_data }),
                $.make('span', 'Custom icon')
            ).addClass('NB-active');
        }
    },

    select_current_color: function () {
        var icon = this.folder ? this.folder_icon : this.feed_icon;
        if (icon && icon.icon_color) {
            $('.NB-folder-icon-color[data-color="' + icon.icon_color + '"]', this.$modal).addClass('NB-active');
        } else {
            $('.NB-folder-icon-color[data-color="#000000"]', this.$modal).addClass('NB-active');
        }
    },

    switch_tab: function (tab_name) {
        $('.NB-modal-tab', this.$modal).removeClass('NB-active');
        $('.NB-modal-tab-' + tab_name, this.$modal).addClass('NB-active');
        $('.NB-tab', this.$modal).removeClass('NB-active');
        $('.NB-tab-' + tab_name, this.$modal).addClass('NB-active');
        this.resize();
    },

    select_preset_icon: function (icon_name, icon_set) {
        icon_set = icon_set || 'lucide';
        this.selected_icon_type = 'preset';
        this.selected_icon_data = icon_name;
        $('.NB-folder-icon-preset', this.$modal).removeClass('NB-active');
        // Select by both icon name and icon set to handle duplicate names between sets
        if (icon_set === 'heroicons-solid') {
            $('.NB-folder-icon-preset[data-icon="' + icon_name + '"][data-icon-set="heroicons-solid"]', this.$modal).addClass('NB-active');
        } else {
            $('.NB-folder-icon-preset[data-icon="' + icon_name + '"]:not([data-icon-set])', this.$modal).addClass('NB-active');
        }
        $('.NB-folder-icon-emoji-option', this.$modal).removeClass('NB-active');

        var icon_data = {
            icon_type: 'preset',
            icon_data: icon_name,
            icon_set: icon_set,
            icon_color: this.selected_icon_color || '#000000'
        };

        if (this.folder) {
            this.folder_icon = _.extend({ folder_title: this.folder_title }, icon_data);
        } else if (this.feed) {
            this.feed_icon = _.extend({ feed_id: this.feed_id }, icon_data);
        }
        this.update_header_icon();
        this.save_and_refresh_icon();
    },

    select_emoji_icon: function (emoji) {
        this.selected_icon_type = 'emoji';
        this.selected_icon_data = emoji;
        $('.NB-folder-icon-emoji-option', this.$modal).removeClass('NB-active');
        $('.NB-folder-icon-emoji-option', this.$modal).filter(function () {
            return $(this).data('emoji') === emoji;
        }).addClass('NB-active');
        $('.NB-folder-icon-preset', this.$modal).removeClass('NB-active');

        var icon_data = {
            icon_type: 'emoji',
            icon_data: emoji,
            icon_color: this.selected_icon_color || '#000000'
        };

        if (this.folder) {
            this.folder_icon = _.extend({ folder_title: this.folder_title }, icon_data);
        } else if (this.feed) {
            this.feed_icon = _.extend({ feed_id: this.feed_id }, icon_data);
        }
        this.update_header_icon();
        this.save_and_refresh_icon();
    },

    select_icon_color: function (color) {
        this.selected_icon_color = color;
        $('.NB-folder-icon-color', this.$modal).removeClass('NB-active');
        $('.NB-folder-icon-color[data-color="' + color + '"]', this.$modal).addClass('NB-active');

        // Update icon preview in the grid immediately
        this.update_icon_grid_colors(color);

        if (this.folder) {
            // If no icon is set, use the default folder-open icon with this color
            if (!this.folder_icon || !this.folder_icon.icon_type || this.folder_icon.icon_type === 'none') {
                this.folder_icon = {
                    folder_title: this.folder_title,
                    icon_type: 'preset',
                    icon_data: 'folder-open',
                    icon_set: 'lucide',
                    icon_color: color
                };
            } else {
                this.folder_icon.icon_color = color;
            }
        } else if (this.feed) {
            // If no icon is set, use the default rss icon with this color
            if (!this.feed_icon || !this.feed_icon.icon_type || this.feed_icon.icon_type === 'none') {
                this.feed_icon = {
                    feed_id: this.feed_id,
                    icon_type: 'preset',
                    icon_data: 'rss',
                    icon_set: 'lucide',
                    icon_color: color
                };
            } else {
                this.feed_icon.icon_color = color;
            }
        }

        this.update_header_icon();
        this.save_and_refresh_icon();
    },

    update_icon_grid_colors: function (color) {
        // Use shared icon picker utility
        NEWSBLUR.IconPicker.update_icon_grid_colors(this.$modal, color);
    },

    update_header_icon: function () {
        // Update the icon in the modal header/subtitle (works for both folder and feed)
        var $header_container = $('.NB-modal-subtitle', this.$modal);
        var $header_icon = $header_container.find('.NB-modal-feed-image, .NB-folder-emoji, .NB-folder-icon-colored, .NB-feed-emoji, .NB-feed-icon-colored').first();

        if (!$header_container.length) return;

        // Determine which icon data to use
        var icon = this.folder ? this.folder_icon : this.feed_icon;
        var icon_url = null;
        var icon_color = null;

        if (icon && icon.icon_type && icon.icon_type !== 'none') {
            icon_color = icon.icon_color;
            icon_url = this.folder ? $.make_folder_icon(icon) : $.make_feed_icon(icon);
        } else if (this.folder) {
            icon_url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/folder-open.svg';
        } else if (this.feed) {
            icon_url = $.favicon(this.feed);
        }

        var is_folder = !!this.folder;
        var new_icon = $.make_icon_element({
            icon_url: icon_url,
            icon_color: icon_color,
            image_class: 'NB-modal-feed-image feed_favicon',
            emoji_class: 'NB-modal-feed-image ' + (is_folder ? 'NB-folder-emoji' : 'NB-feed-emoji'),
            colored_class: 'NB-modal-feed-image ' + (is_folder ? 'NB-folder-icon-colored' : 'NB-feed-icon-colored')
        });

        if (new_icon) {
            if ($header_icon.length) {
                $header_icon.replaceWith(new_icon);
            } else {
                $header_container.prepend(new_icon);
            }
        }

        // Show/hide the clear link based on whether there's a custom icon
        var has_custom_icon = !!(icon && icon.icon_type && icon.icon_type !== 'none');
        $('.NB-folder-icon-clear-header', this.$modal).toggle(has_custom_icon);
    },

    save_and_refresh_icon: function () {
        var self = this;

        if (this.folder) {
            // Save folder icon to backend
            NEWSBLUR.assets.save_folder_icon(
                this.folder_title,
                this.folder_icon.icon_type,
                this.folder_icon.icon_data,
                this.folder_icon.icon_color,
                this.folder_icon.icon_set,
                function () {
                    self.refresh_folder_icon_everywhere();
                    $('.NB-folder-icon-clear-header', self.$modal).show();
                }
            );
        } else if (this.feed) {
            // Save feed icon to backend
            NEWSBLUR.assets.save_feed_icon(
                this.feed_id,
                this.feed_icon.icon_type,
                this.feed_icon.icon_data,
                this.feed_icon.icon_color,
                this.feed_icon.icon_set,
                function () {
                    self.refresh_feed_icon_everywhere();
                    $('.NB-folder-icon-clear-header', self.$modal).show();
                }
            );
        }
    },

    refresh_folder_icon_everywhere: function () {
        var self = this;
        var folder_id = 'river:' + this.folder_title;
        var is_custom = $.favicon_is_custom(folder_id);
        var make_icon = function () {
            return $.favicon_el(folder_id, {
                image_class: 'feed_favicon',
                emoji_class: 'NB-folder-emoji',
                colored_class: 'NB-folder-icon-colored'
            });
        };

        // Update sidebar folder
        $('.NB-feedlist .folder_title').each(function () {
            var $folder = $(this);
            var title = $folder.find('.folder_title_text span').text();
            if (title === self.folder_title) {
                var $icon_container = $folder.find('.NB-folder-icon');
                $icon_container.empty().removeClass('NB-has-custom-icon');
                var $icon = make_icon();
                if ($icon) {
                    $icon_container.append($icon);
                }
                if (is_custom) {
                    $icon_container.addClass('NB-has-custom-icon');
                }
            }
        });

        // Update feedbar if viewing this folder
        if (NEWSBLUR.reader.active_folder && NEWSBLUR.reader.active_folder.get('folder_title') === this.folder_title) {
            var $feedbar = $('.NB-feedbar .NB-folder-icon');
            if ($feedbar.length) {
                $feedbar.empty();
                var $icon = make_icon();
                if ($icon) {
                    $feedbar.append($icon);
                }
            }
        }
    },

    refresh_feed_icon_everywhere: function () {
        var self = this;
        var make_icon = function () {
            return $.favicon_el(self.feed, {
                image_class: 'feed_favicon',
                emoji_class: 'feed_favicon NB-feed-emoji',
                colored_class: 'feed_favicon NB-feed-icon-colored'
            });
        };

        // Update sidebar feed
        var feed = this.feed;
        if (feed) {
            // Find the feed in the sidebar and update its favicon
            var $feed_items = $('.NB-feedlist .feed[data-id="' + this.feed_id + '"]');
            $feed_items.each(function () {
                var $feed_item = $(this);
                var $favicon = $feed_item.find('.feed_favicon').first();
                var $icon = make_icon();
                if ($icon && $favicon.length) {
                    $favicon.replaceWith($icon);
                }
            });

            // Trigger feed view update if this is the active feed
            if (NEWSBLUR.reader.active_feed && NEWSBLUR.reader.active_feed == this.feed_id) {
                // Update feedbar favicon
                var $feedbar_icon = $('.NB-feedbar .feed_favicon').first();
                var $icon = make_icon();
                if ($icon && $feedbar_icon.length) {
                    $feedbar_icon.replaceWith($icon);
                }
            }
        }
    },

    handle_icon_upload: function () {
        var self = this;
        var $file_input = $('.NB-folder-icon-file-input', this.$modal);
        var $button = $('.NB-folder-icon-upload-button', this.$modal);
        var $loading = $('.NB-folder-icon-upload-button .NB-loading', this.$modal);
        var $error = $('.NB-folder-icon-upload-error', this.$modal);
        var $preview = $('.NB-folder-icon-upload-preview', this.$modal);
        var file = $file_input[0].files[0];

        if (!file) return;

        // Validate file type
        if (!file.type.match(/^image\/(png|jpeg|gif|webp)$/)) {
            $error.text('Please select a valid image file (PNG, JPG, GIF)').show();
            return;
        }

        // Validate file size (max 5MB)
        if (file.size > 5 * 1024 * 1024) {
            $error.text('Image must be smaller than 5MB').show();
            return;
        }

        // Show loading state
        $error.hide();
        $button.addClass('NB-uploading');
        $loading.addClass('NB-active');

        var formData = new FormData();
        var upload_url;

        if (this.folder) {
            formData.append('folder_title', this.folder_title);
            upload_url = '/reader/upload_folder_icon';
        } else if (this.feed) {
            formData.append('feed_id', this.feed_id);
            upload_url = '/reader/upload_feed_icon';
        }
        formData.append('photo', file);

        $.ajax({
            url: upload_url,
            type: 'POST',
            data: formData,
            processData: false,
            contentType: false,
            success: function (response) {
                $button.removeClass('NB-uploading');
                $loading.removeClass('NB-active');

                if (response.code >= 0) {
                    self.selected_icon_type = 'upload';
                    self.selected_icon_data = response.icon_data;

                    if (self.folder) {
                        self.folder_icon = {
                            folder_title: self.folder_title,
                            icon_type: 'upload',
                            icon_data: response.icon_data,
                            icon_color: self.selected_icon_color || '#000000'
                        };
                        NEWSBLUR.assets.folder_icons[self.folder_title] = self.folder_icon;
                        self.refresh_folder_icon_everywhere();
                    } else if (self.feed) {
                        self.feed_icon = {
                            feed_id: self.feed_id,
                            icon_type: 'upload',
                            icon_data: response.icon_data,
                            icon_color: self.selected_icon_color || '#000000'
                        };
                        NEWSBLUR.assets.feed_icons[self.feed_id] = self.feed_icon;
                        self.refresh_feed_icon_everywhere();
                    }

                    // Show preview
                    $preview.empty().append(
                        $.make('img', { src: 'data:image/png;base64,' + response.icon_data }),
                        $.make('span', 'Uploaded!')
                    ).addClass('NB-active');

                    self.update_header_icon();
                    $('.NB-folder-icon-preset', self.$modal).removeClass('NB-active');
                    $('.NB-folder-icon-emoji-option', self.$modal).removeClass('NB-active');
                    // Show clear link in header
                    $('.NB-folder-icon-clear-header', self.$modal).show();
                } else {
                    $error.text(response.message || 'Upload failed. Please try again.').show();
                }
            },
            error: function (xhr, status, error) {
                $button.removeClass('NB-uploading');
                $loading.removeClass('NB-active');
                $error.text('Upload failed. Please check your connection and try again.').show();
            }
        });

        // Reset file input so same file can be re-selected
        $file_input.val('');
    },

    clear_folder_icon: function () {
        var self = this;
        this.selected_icon_type = 'none';
        this.selected_icon_data = '';
        this.selected_icon_color = '#000000';
        this.folder_icon = { icon_type: 'none' };

        NEWSBLUR.assets.remove_folder_icon(this.folder_title, function () {
            self.update_header_icon();
            self.refresh_folder_icon_everywhere();
            $('.NB-folder-icon-preset', self.$modal).removeClass('NB-active');
            $('.NB-folder-icon-emoji-option', self.$modal).removeClass('NB-active');
            $('.NB-folder-icon-color', self.$modal).removeClass('NB-active');
            // Select default black color
            $('.NB-folder-icon-color[data-color="#000000"]', self.$modal).addClass('NB-active');
            self.update_icon_grid_colors(self.selected_icon_color);
            // Hide the clear link
            $('.NB-folder-icon-clear', self.$modal).hide();
            $('.NB-folder-icon-clear-header', self.$modal).hide();
            // Clear upload preview
            $('.NB-folder-icon-upload-preview', self.$modal).empty().removeClass('NB-active');
        });
    },

    clear_feed_icon: function () {
        var self = this;
        this.selected_icon_type = 'none';
        this.selected_icon_data = '';
        this.selected_icon_color = '#000000';
        this.feed_icon = { icon_type: 'none' };

        NEWSBLUR.assets.remove_feed_icon(this.feed_id, function () {
            self.update_header_icon();
            self.refresh_feed_icon_everywhere();
            $('.NB-folder-icon-preset', self.$modal).removeClass('NB-active');
            $('.NB-folder-icon-emoji-option', self.$modal).removeClass('NB-active');
            $('.NB-folder-icon-color', self.$modal).removeClass('NB-active');
            // Select default black color
            $('.NB-folder-icon-color[data-color="#000000"]', self.$modal).addClass('NB-active');
            self.update_icon_grid_colors(self.selected_icon_color);
            // Hide the clear links
            $('.NB-folder-icon-clear', self.$modal).hide();
            $('.NB-folder-icon-clear-header', self.$modal).hide();
            // Clear upload preview
            $('.NB-folder-icon-upload-preview', self.$modal).empty().removeClass('NB-active');
        });
    },

    handle_change: function (elem, e) {
        var self = this;

        $.targetIs(e, { tagSelector: '.NB-modal-feed-chooser' }, function ($t, $p) {
            var feed_id = $t.val();
            self.first_load = false;
            self.initialize_feed(feed_id);
            self.get_feed_settings();
        });

        $.targetIs(e, { tagSelector: 'input[name=view_settings]' }, function ($t, $p) {
            if (self.folder) {
                self.folder.view_setting({ 'view': $t.val() });
            } else {
                NEWSBLUR.assets.view_setting(self.feed_id, { 'view': $t.val() });
            }
            self.animate_saved();
        });
        $.targetIs(e, { tagSelector: 'input[name=story_layout]' }, function ($t, $p) {
            if (self.folder) {
                self.folder.view_setting({ 'layout': $t.val() });
            } else {
                NEWSBLUR.assets.view_setting(self.feed_id, { 'layout': $t.val() });
            }
            self.animate_saved();
        });
        $.targetIs(e, { tagSelector: 'input[name=auto_mark_read_days]' }, function ($t, $p) {
            self.handle_auto_mark_read_slider_change();
        });
    },

    handle_input: function (elem, e) {
        var self = this;

        // Update slider label in real-time (without saving)
        $.targetIs(e, { tagSelector: 'input[name=auto_mark_read_days]' }, function ($t, $p) {
            self.on_auto_mark_read_slider_input();
        });
    },

    // ===================
    // = Auto-Mark Read  =
    // ===================

    setup_auto_mark_read_for_folder: function () {
        var $section = $('.NB-exception-option-auto-mark-read', this.$modal);

        // Check if user is Archive tier
        if (!NEWSBLUR.Globals.is_archive) {
            $section.find('.NB-auto-mark-read-slider').prop('disabled', true);
            $section.find('.segmented-control').addClass('NB-disabled');
            return;
        }

        this.update_auto_mark_read_ui();
    },

    setup_auto_mark_read_for_feed: function () {
        var $section = $('.NB-exception-option-auto-mark-read', this.$modal);

        // Skip if no feed (shouldn't happen, but guard against it)
        if (!this.feed) {
            return;
        }

        // Skip for starred/social feeds
        if (this.feed.is_starred() || this.feed.is_social()) {
            $section.hide();
            return;
        }

        // Check if user is Archive tier
        if (!NEWSBLUR.Globals.is_archive) {
            $section.find('.NB-auto-mark-read-slider').prop('disabled', true);
            $section.find('.segmented-control').addClass('NB-disabled');
            return;
        }

        this.update_auto_mark_read_ui();
    },

    update_auto_mark_read_ui: function () {
        var $options = $('.NB-auto-mark-read-option', this.$modal);
        var $slider = $('.NB-auto-mark-read-slider', this.$modal);
        var $slider_value = $('.NB-auto-mark-read-slider-value', this.$modal);

        // Calculate default values
        var site_wide_days = NEWSBLUR.Preferences.days_of_unread || 14;
        var default_days = site_wide_days;
        var default_source = 'site-wide preference';

        var auto_mark_days;
        if (this.folder) {
            // For folders, check parent folder first
            var parent_folder_title = this.get_parent_folder_title(this.folder_title);
            if (parent_folder_title) {
                var parent_setting = NEWSBLUR.assets.get_folder_auto_mark_read(parent_folder_title);
                if (parent_setting !== null && parent_setting !== undefined) {
                    default_days = parent_setting;
                    default_source = parent_folder_title;
                }
            }
            auto_mark_days = NEWSBLUR.assets.get_folder_auto_mark_read(this.folder_title);
        } else {
            // For feeds, check folder first
            var folders = NEWSBLUR.assets.get_feed_folders(this.feed_id);
            var feed_folder_title = folders && folders.length > 0 ? folders[0] : null;
            if (feed_folder_title) {
                var folder_setting = NEWSBLUR.assets.get_folder_auto_mark_read(feed_folder_title);
                if (folder_setting !== null && folder_setting !== undefined) {
                    default_days = folder_setting;
                    default_source = feed_folder_title;
                }
            }
            auto_mark_days = this.feed.get('auto_mark_read_days');
        }

        // Determine mode: default (null/undefined), never (0), or days (positive number)
        var mode = 'default';
        if (auto_mark_days === 0) {
            mode = 'never';
        } else if (auto_mark_days !== null && auto_mark_days !== undefined) {
            mode = 'days';
        }

        // Update segmented control selection
        $options.removeClass('NB-active');
        $('.NB-auto-mark-read-' + mode, this.$modal).addClass('NB-active');

        // Update slider value based on mode
        var slider_value;
        var display_days;
        if (mode === 'default') {
            display_days = default_days === 0 ? 400 : default_days;
            slider_value = display_days;
        } else if (mode === 'never') {
            slider_value = 400;
        } else {
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
            // Normal days zone
            $slider.css('background', 'linear-gradient(to right, #4a90d9 0%, #4a90d9 ' + percent + '%, #e0e0e0 ' + percent + '%, #e0e0e0 ' + never_zone_start + '%, #d4d0e8 ' + never_zone_start + '%, #d4d0e8 100%)');
        }
    },

    get_parent_folder_title: function (folder_title) {
        // Folders use " - " as separator for nesting
        var parts = folder_title.split(' - ');
        if (parts.length > 1) {
            parts.pop();
            return parts.join(' - ');
        }
        return null;
    },

    get_auto_mark_read_defaults: function () {
        var site_wide_days = NEWSBLUR.Preferences.days_of_unread || 14;
        var default_days = site_wide_days;
        var default_source = 'site-wide preference';

        if (this.folder) {
            var parent_folder_title = this.get_parent_folder_title(this.folder_title);
            if (parent_folder_title) {
                var parent_setting = NEWSBLUR.assets.get_folder_auto_mark_read(parent_folder_title);
                if (parent_setting !== null && parent_setting !== undefined) {
                    default_days = parent_setting;
                    default_source = parent_folder_title;
                }
            }
        } else {
            var folders = NEWSBLUR.assets.get_feed_folders(this.feed_id);
            var feed_folder_title = folders && folders.length > 0 ? folders[0] : null;
            if (feed_folder_title) {
                var folder_setting = NEWSBLUR.assets.get_folder_auto_mark_read(feed_folder_title);
                if (folder_setting !== null && folder_setting !== undefined) {
                    default_days = folder_setting;
                    default_source = feed_folder_title;
                }
            }
        }

        return { default_days: default_days, default_source: default_source };
    },

    handle_auto_mark_read_option_click: function ($option) {
        if (!NEWSBLUR.Globals.is_archive) {
            this.flash_auto_mark_read_upgrade_notice();
            return;
        }

        var value = $option.data('value');
        var $options = $('.NB-auto-mark-read-option', this.$modal);
        var $slider = $('.NB-auto-mark-read-slider', this.$modal);
        var $slider_value = $('.NB-auto-mark-read-slider-value', this.$modal);

        // Update selection
        $options.removeClass('NB-active');
        $option.addClass('NB-active');

        var defaults = this.get_auto_mark_read_defaults();
        var default_days = defaults.default_days;
        var default_source = defaults.default_source;

        var days;
        var slider_value;

        if (value === 'default') {
            days = null;
            slider_value = default_days === 0 ? 400 : default_days;
            this.update_slider_status_text($slider_value, 'default', default_days, default_source);
        } else if (value === 'never') {
            days = 0;
            slider_value = 400;
            this.update_slider_status_text($slider_value, 'never', 0, default_source);
        } else {
            var current_slider = parseInt($slider.val(), 10);
            days = current_slider > 365 ? 30 : current_slider;
            slider_value = days;
            this.update_slider_status_text($slider_value, 'days', days, default_source);
        }

        $slider.val(slider_value);
        this.update_slider_gradient($slider, slider_value);

        this.save_auto_mark_read_setting(days);
    },

    handle_auto_mark_read_slider_change: function () {
        this.on_auto_mark_read_slider_input(true);
    },

    on_auto_mark_read_slider_input: function (save) {
        var $slider = $('.NB-auto-mark-read-slider', this.$modal);
        var slider_val = parseInt($slider.val(), 10);
        var $slider_value = $('.NB-auto-mark-read-slider-value', this.$modal);
        var $options = $('.NB-auto-mark-read-option', this.$modal);

        var is_never = slider_val > 365;
        var days = is_never ? 0 : slider_val;

        this.update_slider_gradient($slider, slider_val);

        if (!NEWSBLUR.Globals.is_archive) {
            this.flash_auto_mark_read_upgrade_notice();
            return;
        }

        var defaults = this.get_auto_mark_read_defaults();
        var default_source = defaults.default_source;

        // Auto-select appropriate option based on slider position
        $options.removeClass('NB-active');
        if (is_never) {
            $('.NB-auto-mark-read-never', this.$modal).addClass('NB-active');
            this.update_slider_status_text($slider_value, 'never', 0, default_source);
        } else {
            $('.NB-auto-mark-read-days', this.$modal).addClass('NB-active');
            this.update_slider_status_text($slider_value, 'days', slider_val, default_source);
        }

        // Save on change event (not input)
        if (save) {
            this.save_auto_mark_read_setting(days);
        }
    },

    flash_auto_mark_read_upgrade_notice: function () {
        var $notice = $('.NB-auto-mark-read-upgrade-notice', this.$modal);
        $notice.addClass('NB-flash');
        setTimeout(function () {
            $notice.removeClass('NB-flash');
        }, 600);
    },

    save_auto_mark_read_setting: function (days) {
        var self = this;
        var $status = $('.NB-exception-option-auto-mark-read .NB-exception-option-status', this.$modal);

        if (this.folder) {
            NEWSBLUR.assets.save_folder_auto_mark_read(this.folder_title, days, function () {
                self.animate_auto_mark_read_saved($status);
                // Refresh all feeds in the folder, then reload after refresh completes
                var folder = NEWSBLUR.assets.get_folder(self.folder_title);
                if (folder) {
                    var feed_ids = folder.feed_ids_in_folder();
                    NEWSBLUR.reader.force_feeds_refresh(function () {
                        NEWSBLUR.reader.reload_feed();
                    }, false, feed_ids);
                } else {
                    NEWSBLUR.reader.reload_feed();
                }
            });
        } else if (this.feed) {
            NEWSBLUR.assets.save_feed_auto_mark_read(this.feed_id, days, function () {
                // Update the feed model
                self.feed.set('auto_mark_read_days', days);
                self.animate_auto_mark_read_saved($status);
                // Refresh feed to recalculate unread counts, then reload after refresh completes
                NEWSBLUR.reader.force_feeds_refresh(function () {
                    NEWSBLUR.reader.reload_feed();
                }, false, self.feed_id);
            });
        }
    },

    animate_auto_mark_read_saved: function ($status) {
        $status.text('Saved').animate({
            'opacity': 1
        }, {
            'queue': false,
            'duration': 600,
            'complete': function () {
                _.delay(function () {
                    $status.animate({ 'opacity': 0 }, { 'queue': false, 'duration': 1000 });
                }, 300);
            }
        });
    }

});

// Alias for folder icon editor functionality
NEWSBLUR.ReaderFolderIconEditor = function(options) {
    return new NEWSBLUR.ReaderFeedException(null, options);
};
