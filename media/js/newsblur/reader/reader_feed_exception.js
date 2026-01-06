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

        $('input[name=view_settings]', this.$modal).each(function () {
            if ($(this).val() == view_setting) {
                $(this).prop('checked', true);
                return false;
            }
        });
        $('input[name=story_layout]', this.$modal).each(function () {
            if ($(this).val() == story_layout) {
                $(this).prop('checked', true);
                return false;
            }
        });

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
            $.make('div', { className: 'NB-tab NB-tab-settings NB-active' }),
            $.make('div', { className: 'NB-tab NB-tab-folder-icon' }),
            $.make('div', { className: 'NB-fieldset NB-exception-option NB-exception-option-view NB-modal-submit NB-settings-only' }, [
                $.make('h5', [
                    $.make('div', { className: 'NB-exception-option-status NB-right' }),
                    $.make('div', { className: 'NB-exception-option-meta' }),
                    'View settings'
                ]),
                $.make('div', { className: 'NB-fieldset-fields' }, [
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Reading view'
                        ]),
                        $.make('div', { className: 'NB-preference-options NB-view-settings' }, [
                            $.make('div', { className: "NB-view-setting-original" }, [
                                $.make('label', { 'for': 'NB-preference-view-1' }, [
                                    $.make('input', { id: 'NB-preference-view-1', type: 'radio', name: 'view_settings', value: 'page' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_original_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Original")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-2' }, [
                                    $.make('input', { id: 'NB-preference-view-2', type: 'radio', name: 'view_settings', value: 'feed' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_feed_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Feed")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-3' }, [
                                    $.make('input', { id: 'NB-preference-view-3', type: 'radio', name: 'view_settings', value: 'text' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_text_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Text")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-view-4' }, [
                                    $.make('input', { id: 'NB-preference-view-4', type: 'radio', name: 'view_settings', value: 'story' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_story_active.png' }),
                                    $.make("div", { className: "NB-view-title" }, "Story")
                                ])
                            ])
                        ]),
                        $.make('div', { className: 'NB-preference-label' }, [
                            'Story layout'
                        ]),
                        $.make('div', { className: 'NB-preference-options NB-view-settings' }, [
                            $.make('div', { className: "" }, [
                                $.make('label', { 'for': 'NB-preference-layout-1' }, [
                                    $.make('input', { id: 'NB-preference-layout-1', type: 'radio', name: 'story_layout', value: 'full' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_full_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Full")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-2' }, [
                                    $.make('input', { id: 'NB-preference-layout-2', type: 'radio', name: 'story_layout', value: 'split' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_split_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Split")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-3' }, [
                                    $.make('input', { id: 'NB-preference-layout-3', type: 'radio', name: 'story_layout', value: 'list' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_list_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "List")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-4' }, [
                                    $.make('input', { id: 'NB-preference-layout-4', type: 'radio', name: 'story_layout', value: 'grid' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_grid_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Grid")
                                ])
                            ]),
                            $.make('div', [
                                $.make('label', { 'for': 'NB-preference-layout-5' }, [
                                    $.make('input', { id: 'NB-preference-layout-5', type: 'radio', name: 'story_layout', value: 'magazine' }),
                                    $.make("img", { src: NEWSBLUR.Globals.MEDIA_URL + '/img/icons/circular/nav_story_magazine_active.png' }),
                                    $.make("div", { className: "NB-layout-title" }, "Magazine")
                                ])
                            ])
                        ])
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
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-unread', className: 'NB-exception-label' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'Unread+Focus:'
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-unread', className: 'NB-exception-input-unread NB-input', name: 'folder_rss_unread_url', value: this.folder.rss_url('unread') })
                    ]),
                    $.make('div', { className: 'NB-exception-input-wrapper' }, [
                        $.make('div', { className: 'NB-loading' }),
                        $.make('label', { 'for': 'NB-exception-input-focus', className: 'NB-exception-label' }, [
                            $.make('div', { className: 'NB-folder-icon' }),
                            'Only Focus:'
                        ]),
                        $.make('input', { type: 'text', id: 'NB-exception-input-focus', className: 'NB-exception-input-focus NB-input', name: 'folder_rss_focus_url', value: this.folder.rss_url('focus') })
                    ]),
                    (!NEWSBLUR.Globals.is_premium && $.make('div', { className: 'NB-premium-only' }, [
                        $.make('div', { className: 'NB-premium-only-divider' }),
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
                NEWSBLUR.reader.open_feedchooser_modal({ premium_only: true });
            });
        });
        // Folder icon tab handlers
        $.targetIs(e, { tagSelector: '.NB-modal-tab-settings' }, function ($t, $p) {
            e.preventDefault();
            self.switch_folder_tab('settings');
        });
        $.targetIs(e, { tagSelector: '.NB-modal-tab-folder-icon' }, function ($t, $p) {
            e.preventDefault();
            self.switch_folder_tab('folder-icon');
        });
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
            self.clear_folder_icon();
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

    setup_folder_tabs: function () {
        var self = this;
        var $settings_tab = $('.NB-tab-settings', this.$modal);
        var $folder_icon_tab = $('.NB-tab-folder-icon', this.$modal);

        // Move folder-specific content into the Settings tab
        var $view_settings = $('.NB-exception-option-view', this.$modal).detach();
        var $folder_rss = $('.NB-exception-option-feed', this.$modal).detach();
        $settings_tab.append($view_settings).append($folder_rss);

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
        var has_icon = this.folder_icon && this.folder_icon.icon_type && this.folder_icon.icon_type !== 'none';
        $('.NB-folder-icon-clear-header', this.$modal).toggle(has_icon);

        // Add click handler for header clear link
        $('.NB-folder-icon-clear-header', this.$modal).on('click', function (e) {
            e.preventDefault();
            self.clear_folder_icon();
        });

        // Add change handler for file input
        $('.NB-folder-icon-file-input', this.$modal).on('change', _.bind(this.handle_folder_icon_upload, this));
    },

    make_folder_icon_tab: function () {
        return $.make('div', { className: 'NB-folder-icon-editor' }, [
            $.make('div', { className: 'NB-folder-icon-section NB-folder-icon-upload-section' }, [
                $.make('div', { className: 'NB-folder-icon-upload-container' }, [
                    $.make('input', { type: 'file', className: 'NB-folder-icon-file-input', accept: 'image/*' }),
                    $.make('div', { className: 'NB-folder-icon-upload-button' }, [
                        $.make('div', { className: 'NB-folder-icon-upload-icon' }),
                        $.make('div', { className: 'NB-folder-icon-upload-text' }, [
                            $.make('span', { className: 'NB-folder-icon-upload-label' }, 'Upload Custom Image'),
                            $.make('span', { className: 'NB-folder-icon-upload-hint' }, 'PNG, JPG, or GIF')
                        ]),
                        $.make('div', { className: 'NB-loading' })
                    ]),
                    $.make('div', { className: 'NB-folder-icon-upload-preview' }),
                    $.make('div', { className: 'NB-folder-icon-upload-error' })
                ])
            ]),
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Color'),
                this.make_color_palette()
            ]),
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Outline Icons'),
                this.make_preset_icons()
            ]),
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Filled Icons'),
                this.make_filled_icons()
            ]),
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Emoji'),
                this.make_emoji_picker()
            ])
        ]);
    },

    make_preset_icons: function () {
        var self = this;
        // Lucide outline icons organized by category with labels
        var icon_categories = [
            { label: 'Files', icons: ['folder', 'folder-open', 'file', 'file-text', 'files', 'archive', 'folder-archive', 'folder-check', 'folder-cog', 'folder-heart'] },
            { label: 'Places', icons: ['home', 'building', 'building-2', 'store', 'landmark', 'factory', 'warehouse', 'castle', 'church', 'hospital'] },
            { label: 'Favorites', icons: ['star', 'heart', 'bookmark', 'flag', 'tag', 'tags', 'award', 'crown', 'gem', 'diamond'] },
            { label: 'Reading', icons: ['book', 'book-open', 'book-marked', 'library', 'newspaper', 'scroll', 'notebook', 'graduation-cap', 'school', 'brain'] },
            { label: 'Audio', icons: ['music', 'headphones', 'mic', 'radio', 'podcast', 'disc', 'album', 'bluetooth', 'signal', 'atom'] },
            { label: 'Visual', icons: ['video', 'film', 'tv', 'monitor', 'camera', 'image', 'images', 'eye', 'gamepad-2', 'dice-5'] },
            { label: 'Travel', icons: ['trophy', 'medal', 'target', 'puzzle', 'bike', 'ship', 'rocket', 'plane', 'train', 'bus'] },
            { label: 'Tech', icons: ['code', 'terminal', 'database', 'server', 'cpu', 'hard-drive', 'wifi', 'globe', 'rss', 'git-merge'] },
            { label: 'Nature', icons: ['sun', 'moon', 'cloud', 'umbrella', 'tree-pine', 'flower-2', 'leaf', 'droplets', 'snowflake', 'wind'] },
            { label: 'Food', icons: ['coffee', 'utensils', 'chef-hat', 'pizza', 'apple', 'cake', 'cookie', 'ice-cream-cone', 'thermometer', 'flame'] },
            { label: 'Shopping', icons: ['shopping-cart', 'shopping-bag', 'gift', 'package', 'wallet', 'credit-card', 'coins', 'piggy-bank', 'box', 'briefcase'] },
            { label: 'Social', icons: ['mail', 'message-square', 'phone', 'at-sign', 'send', 'inbox', 'users', 'user', 'contact', 'hand'] }
        ];

        var $container = $.make('div', { className: 'NB-folder-icon-presets-container' });

        _.each(icon_categories, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-preset-row' }, [
                $.make('div', { className: 'NB-folder-icon-preset-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-preset-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-preset-items');
            _.each(category.icons, function (icon_name) {
                var $icon = $.make('div', { className: 'NB-folder-icon-preset', 'data-icon': icon_name }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/lucide/' + icon_name + '.svg' })
                ]);
                $items.append($icon);
            });
            $container.append($row);
        });

        return $container;
    },

    make_filled_icons: function () {
        var self = this;
        // Heroicons solid icons organized by category with accurate labels
        var icon_categories = [
            { label: 'Files', icons: ['folder', 'folder-open', 'document', 'document-text', 'document-chart-bar', 'archive-box', 'clipboard', 'clipboard-document', 'inbox', 'rectangle-stack'] },
            { label: 'Places', icons: ['home', 'building-office', 'building-library', 'building-storefront', 'map', 'map-pin', 'globe-alt', 'globe-americas', 'academic-cap', 'briefcase'] },
            { label: 'People', icons: ['users', 'user', 'face-smile', 'face-frown', 'identification', 'hand-raised', 'hand-thumb-up'] },
            { label: 'Messages', icons: ['envelope', 'phone', 'megaphone', 'chat-bubble-left', 'chat-bubble-bottom-center', 'chat-bubble-left-right', 'paper-airplane', 'at-symbol', 'hashtag', 'signal'] },
            { label: 'Media', icons: ['musical-note', 'film', 'camera', 'photo', 'video-camera', 'tv', 'radio', 'play', 'speaker-wave', 'microphone'] },
            { label: 'Markers', icons: ['star', 'heart', 'bookmark', 'flag', 'tag', 'sparkles', 'trophy', 'gift', 'ticket', 'cake'] },
            { label: 'Creative', icons: ['book-open', 'newspaper', 'pencil', 'paint-brush', 'scissors', 'paper-clip', 'light-bulb', 'puzzle-piece', 'swatch', 'eye'] },
            { label: 'Finance', icons: ['shopping-cart', 'wallet', 'banknotes', 'credit-card', 'currency-dollar', 'receipt-percent', 'calculator', 'chart-bar', 'chart-pie', 'table-cells'] },
            { label: 'Devices', icons: ['computer-desktop', 'device-phone-mobile', 'device-tablet', 'printer', 'server', 'server-stack', 'cpu-chip', 'wifi', 'code-bracket', 'command-line'] },
            { label: 'Tools', icons: ['cog-6-tooth', 'wrench', 'adjustments-horizontal', 'bars-3', 'magnifying-glass', 'key', 'lock-closed', 'lock-open', 'bell', 'trash'] },
            { label: 'Security', icons: ['finger-print', 'shield-check', 'link', 'qr-code', 'rss'] },
            { label: 'Weather', icons: ['sun', 'moon', 'cloud', 'fire', 'bolt', 'bolt-slash'] },
            { label: 'Science', icons: ['beaker', 'bug-ant', 'scale', 'lifebuoy'] },
            { label: 'Objects', icons: ['truck', 'rocket-launch', 'cube', 'square-2-stack', 'language', 'clock', 'calendar'] },
            { label: 'Arrows', icons: ['arrow-path', 'arrow-down-tray', 'arrow-up-tray', 'arrow-up-circle', 'arrow-down-circle', 'backspace'] },
            { label: 'Status', icons: ['check-circle', 'x-circle', 'plus-circle', 'minus-circle', 'question-mark-circle', 'exclamation-circle', 'exclamation-triangle', 'information-circle'] }
        ];

        var $container = $.make('div', { className: 'NB-folder-icon-filled-container' });

        _.each(icon_categories, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-filled-row' }, [
                $.make('div', { className: 'NB-folder-icon-filled-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-filled-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-filled-items');
            _.each(category.icons, function (icon_name) {
                var $icon = $.make('div', { className: 'NB-folder-icon-preset NB-folder-icon-filled', 'data-icon': icon_name, 'data-icon-set': 'heroicons-solid' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/heroicons-solid/' + icon_name + '.svg' })
                ]);
                $items.append($icon);
            });
            $container.append($row);
        });

        return $container;
    },

    make_emoji_picker: function () {
        // Emojis organized by category with labels
        var emoji_categories = [
            { label: 'Files', emojis: ['📁', '📂', '📚', '📖', '📰', '📄', '📑', '📋', '📝', '✏️'] },
            { label: 'Tech', emojis: ['💻', '📱', '📺', '🎬', '🎵', '🎧', '🎮', '📷', '📹', '🖨️'] },
            { label: 'Stars', emojis: ['⭐', '🌟', '✨', '💫', '⚡', '🔥', '💥', '❄️', '🌈', '🎇'] },
            { label: 'Weather', emojis: ['☀️', '🌙', '☁️', '🌧️', '⛈️', '🌪️', '🌊', '💧', '🌤️', '🌥️'] },
            { label: 'Nature', emojis: ['🌲', '🌳', '🌴', '🌻', '🌺', '🌸', '🌷', '🌹', '🍀', '🌿'] },
            { label: '', emojis: ['🍂', '🍁', '🌵', '🌾', '🌱', '🪴', '🎋', '🎍', '🍃', '☘️'] },
            { label: 'Food', emojis: ['☕', '🍵', '🍺', '🍷', '🥤', '🧃', '🍽️', '🍴', '🥢', '🧂'] },
            { label: '', emojis: ['🍕', '🍔', '🍟', '🌮', '🍜', '🍣', '🍰', '🍩', '🍎', '🍇'] },
            { label: 'Animals', emojis: ['🐶', '🐱', '🐦', '🐟', '🦋', '🐝', '🦊', '🐼', '🦁', '🐸'] },
            { label: '', emojis: ['🦄', '🐯', '🐻', '🐨', '🐰', '🦉', '🦅', '🐢', '🐬', '🦈'] },
            { label: 'Places', emojis: ['🏠', '🏢', '🏫', '🏥', '🏰', '⛪', '🕌', '🗼', '🏛️', '🎪'] },
            { label: 'Transport', emojis: ['✈️', '🚗', '🚲', '🚀', '⛵', '🚂', '🚁', '🛸', '🏎️', '🚌'] },
            { label: 'Sports', emojis: ['⚽', '🏀', '🎾', '🎯', '🏆', '🎭', '🎨', '🎸', '🎹', '🏋️'] },
            { label: 'Hearts', emojis: ['❤️', '💛', '💚', '💙', '💜', '🧡', '🖤', '🤍', '💖', '💝'] },
            { label: 'Status', emojis: ['✅', '❌', '⚠️', 'ℹ️', '❓', '🔔', '🔒', '🔑', '💡', '🎁'] },
            { label: 'Objects', emojis: ['💰', '💼', '🎓', '🏅', '💎', '🛒', '🌍', '🌎', '🌏', '🗺️'] },
            { label: 'Faces', emojis: ['😀', '😊', '🥳', '🤔', '😎', '🤩', '🙄', '😴', '🤗', '🥰'] },
            { label: 'Gestures', emojis: ['👍', '👎', '👋', '✋', '🤝', '🙏', '👏', '🎉', '🎊', '🔖'] }
        ];

        var $container = $.make('div', { className: 'NB-folder-icon-emojis-container' });

        _.each(emoji_categories, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-emoji-row' }, [
                $.make('div', { className: 'NB-folder-icon-emoji-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-emoji-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-emoji-items');
            _.each(category.emojis, function (emoji) {
                var $emoji = $.make('div', { className: 'NB-folder-icon-emoji-option', 'data-emoji': emoji }, emoji);
                $items.append($emoji);
            });
            $container.append($row);
        });

        return $container;
    },

    make_color_palette: function () {
        // Color palette organized by columns (each column is one hue, rows go light to dark)
        // 12 columns: Gray, Red, Pink, Purple, Indigo, Blue, Cyan, Teal, Green, Lime, Yellow, Orange
        var colors = [
            // Row 1: Lightest
            '#f5f5f5', '#ffcdd2', '#f8bbd0', '#e1bee7', '#c5cae9', '#bbdefb', '#b3e5fc', '#b2dfdb', '#c8e6c9', '#dcedc8', '#fff9c4', '#ffe0b2',
            // Row 2: Light
            '#e0e0e0', '#ef9a9a', '#f48fb1', '#ce93d8', '#9fa8da', '#90caf9', '#81d4fa', '#80cbc4', '#a5d6a7', '#c5e1a5', '#fff59d', '#ffcc80',
            // Row 3: Medium-Light
            '#bdbdbd', '#e57373', '#f06292', '#ba68c8', '#7986cb', '#64b5f6', '#4fc3f7', '#4db6ac', '#81c784', '#aed581', '#fff176', '#ffb74d',
            // Row 4: Medium
            '#9e9e9e', '#f44336', '#ec407a', '#ab47bc', '#5c6bc0', '#42a5f5', '#29b6f6', '#26a69a', '#66bb6a', '#9ccc65', '#ffee58', '#ffa726',
            // Row 5: Medium-Dark
            '#757575', '#e53935', '#d81b60', '#8e24aa', '#3f51b5', '#1e88e5', '#039be5', '#00897b', '#43a047', '#7cb342', '#fdd835', '#ff9800',
            // Row 6: Dark
            '#616161', '#c62828', '#ad1457', '#6a1b9a', '#303f9f', '#1565c0', '#0277bd', '#00695c', '#2e7d32', '#558b2f', '#f9a825', '#ef6c00',
            // Row 7: Darkest
            '#424242', '#b71c1c', '#880e4f', '#4a148c', '#1a237e', '#0d47a1', '#01579b', '#004d40', '#1b5e20', '#33691e', '#f57f17', '#e65100'
        ];

        var $colors = $.make('div', { className: 'NB-folder-icon-colors-grid' });
        _.each(colors, function (color) {
            var $color = $.make('div', {
                className: 'NB-folder-icon-color',
                style: 'background-color: ' + color + (color === '#ffffff' ? '; border: 1px solid #ddd' : ''),
                'data-color': color
            });
            $colors.append($color);
        });

        return $colors;
    },

    select_current_icon: function () {
        if (!this.folder_icon || !this.folder_icon.icon_type || this.folder_icon.icon_type === 'none') return;

        if (this.folder_icon.icon_type === 'preset') {
            var icon_set = this.folder_icon.icon_set || 'lucide';
            if (icon_set === 'heroicons-solid') {
                $('.NB-folder-icon-preset[data-icon="' + this.folder_icon.icon_data + '"][data-icon-set="heroicons-solid"]', this.$modal).addClass('NB-active');
            } else {
                $('.NB-folder-icon-preset[data-icon="' + this.folder_icon.icon_data + '"]:not([data-icon-set])', this.$modal).addClass('NB-active');
            }
        } else if (this.folder_icon.icon_type === 'emoji') {
            var icon_data = this.folder_icon.icon_data;
            $('.NB-folder-icon-emoji-option', this.$modal).each(function () {
                if ($(this).data('emoji') === icon_data) {
                    $(this).addClass('NB-active');
                }
            });
        }
    },

    select_current_color: function () {
        if (this.folder_icon && this.folder_icon.icon_color) {
            $('.NB-folder-icon-color[data-color="' + this.folder_icon.icon_color + '"]', this.$modal).addClass('NB-active');
        } else {
            $('.NB-folder-icon-color[data-color="#000000"]', this.$modal).addClass('NB-active');
        }
    },

    switch_folder_tab: function (tab_name) {
        $('.NB-modal-tab', this.$modal).removeClass('NB-active');
        $('.NB-modal-tab-' + tab_name, this.$modal).addClass('NB-active');
        $('.NB-tab', this.$modal).removeClass('NB-active');
        $('.NB-tab-' + tab_name, this.$modal).addClass('NB-active');
        this.resize();
    },

    select_preset_icon: function (icon_name, icon_set) {
        var self = this;
        icon_set = icon_set || 'lucide';
        this.selected_icon_type = 'preset';
        this.selected_icon_data = icon_name;
        this.selected_icon_set = icon_set;
        $('.NB-folder-icon-preset', this.$modal).removeClass('NB-active');
        // Select by both icon name and icon set to handle duplicate names between sets
        if (icon_set === 'heroicons-solid') {
            $('.NB-folder-icon-preset[data-icon="' + icon_name + '"][data-icon-set="heroicons-solid"]', this.$modal).addClass('NB-active');
        } else {
            $('.NB-folder-icon-preset[data-icon="' + icon_name + '"]:not([data-icon-set])', this.$modal).addClass('NB-active');
        }
        $('.NB-folder-icon-emoji-option', this.$modal).removeClass('NB-active');

        this.folder_icon = {
            folder_title: this.folder_title,
            icon_type: 'preset',
            icon_data: icon_name,
            icon_set: icon_set,
            icon_color: this.selected_icon_color || '#000000'
        };
        this.update_header_icon();
        this.save_and_refresh_icon();
    },

    select_emoji_icon: function (emoji) {
        var self = this;
        this.selected_icon_type = 'emoji';
        this.selected_icon_data = emoji;
        $('.NB-folder-icon-emoji-option', this.$modal).removeClass('NB-active');
        $('.NB-folder-icon-emoji-option', this.$modal).filter(function () {
            return $(this).data('emoji') === emoji;
        }).addClass('NB-active');
        $('.NB-folder-icon-preset', this.$modal).removeClass('NB-active');

        this.folder_icon = {
            folder_title: this.folder_title,
            icon_type: 'emoji',
            icon_data: emoji,
            icon_color: this.selected_icon_color || '#000000'
        };
        this.update_header_icon();
        this.save_and_refresh_icon();
    },

    select_icon_color: function (color) {
        var self = this;
        this.selected_icon_color = color;
        $('.NB-folder-icon-color', this.$modal).removeClass('NB-active');
        $('.NB-folder-icon-color[data-color="' + color + '"]', this.$modal).addClass('NB-active');

        // Update icon preview in the grid immediately
        this.update_icon_grid_colors(color);

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

        this.update_header_icon();
        this.save_and_refresh_icon();
    },

    update_icon_grid_colors: function (color) {
        // Apply color tint to all preset icons in the grid using mask-image
        var has_color = color && color !== '#000000';

        $('.NB-folder-icon-preset img', this.$modal).each(function () {
            var $img = $(this);
            var icon_url = $img.attr('src');

            if (has_color) {
                // Replace img with colored span using mask-image
                var $colored = $.make('span', { className: 'NB-folder-icon-colored-preview' });
                $colored.css({
                    'display': 'inline-block',
                    'width': '20px',
                    'height': '20px',
                    'background-color': color,
                    '-webkit-mask-image': 'url(' + icon_url + ')',
                    'mask-image': 'url(' + icon_url + ')',
                    '-webkit-mask-size': 'contain',
                    'mask-size': 'contain',
                    '-webkit-mask-repeat': 'no-repeat',
                    'mask-repeat': 'no-repeat',
                    '-webkit-mask-position': 'center',
                    'mask-position': 'center'
                });
                $colored.attr('data-original-src', icon_url);
                $img.replaceWith($colored);
            }
        });

        // Also handle already-colored previews
        $('.NB-folder-icon-preset .NB-folder-icon-colored-preview', this.$modal).each(function () {
            var $preview = $(this);
            if (has_color) {
                $preview.css('background-color', color);
            } else {
                // Restore to original img
                var icon_url = $preview.attr('data-original-src');
                var $img = $.make('img', { src: icon_url });
                $preview.replaceWith($img);
            }
        });
    },

    update_header_icon: function () {
        // Update the folder icon in the modal header/subtitle
        var $header_container = $('.NB-modal-subtitle', this.$modal);
        var $header_icon = $header_container.find('.NB-modal-feed-image, .NB-folder-emoji, .NB-folder-icon-colored').first();

        if (!$header_container.length) return;

        var new_icon;
        if (this.folder_icon && this.folder_icon.icon_type && this.folder_icon.icon_type !== 'none') {
            var icon_color = this.folder_icon.icon_color;
            var has_color = icon_color && icon_color !== '#000000';

            if (this.folder_icon.icon_type === 'preset') {
                var icon_set = this.folder_icon.icon_set || 'lucide';
                var icon_url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/' + icon_set + '/' + this.folder_icon.icon_data + '.svg';
                if (has_color) {
                    // Use mask-image for colored icons
                    new_icon = $.make('span', { className: 'NB-modal-feed-image NB-folder-icon-colored' });
                    new_icon.css({
                        'background-color': icon_color,
                        '-webkit-mask-image': 'url(' + icon_url + ')',
                        'mask-image': 'url(' + icon_url + ')'
                    });
                } else {
                    new_icon = $.make('img', {
                        className: 'NB-modal-feed-image feed_favicon',
                        src: icon_url
                    });
                }
            } else if (this.folder_icon.icon_type === 'emoji') {
                new_icon = $.make('span', { className: 'NB-modal-feed-image NB-folder-emoji' }, this.folder_icon.icon_data);
            } else if (this.folder_icon.icon_type === 'upload') {
                new_icon = $.make('img', {
                    className: 'NB-modal-feed-image feed_favicon',
                    src: 'data:image/png;base64,' + this.folder_icon.icon_data
                });
            }
        } else {
            // Default folder icon
            new_icon = $.make('img', {
                className: 'NB-modal-feed-image feed_favicon',
                src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/folder-open.svg'
            });
        }

        if (new_icon) {
            if ($header_icon.length) {
                $header_icon.replaceWith(new_icon);
            } else {
                $header_container.prepend(new_icon);
            }
        }

        // Show/hide the clear link based on whether there's a custom icon
        var has_custom_icon = this.folder_icon && this.folder_icon.icon_type && this.folder_icon.icon_type !== 'none';
        $('.NB-folder-icon-clear-header', this.$modal).toggle(has_custom_icon);
    },

    save_and_refresh_icon: function () {
        var self = this;
        // Save to backend
        NEWSBLUR.assets.save_folder_icon(
            this.folder_title,
            this.folder_icon.icon_type,
            this.folder_icon.icon_data,
            this.folder_icon.icon_color,
            this.folder_icon.icon_set,
            function () {
                // Refresh folder icon everywhere
                self.refresh_folder_icon_everywhere();
                // Show the clear link if not already visible
                if (!$('.NB-folder-icon-clear', self.$modal).length) {
                    $('.NB-folder-icon-header', self.$modal).append(
                        $.make('a', { className: 'NB-folder-icon-clear', href: '#' }, 'Clear icon')
                    );
                } else {
                    $('.NB-folder-icon-clear', self.$modal).show();
                }
            }
        );
    },

    refresh_folder_icon_everywhere: function () {
        var self = this;
        var icon_url = $.favicon('river:' + this.folder_title);
        var is_preset_icon = icon_url && (icon_url.indexOf('/lucide/') !== -1 || icon_url.indexOf('/heroicons-solid/') !== -1);
        var is_custom = icon_url && (icon_url.indexOf('emoji:') === 0 || is_preset_icon || icon_url.indexOf('data:') === 0);
        var icon_color = this.folder_icon ? this.folder_icon.icon_color : null;
        var has_color = icon_color && icon_color !== '#000000';

        // Update sidebar folder
        $('.NB-feedlist .folder_title').each(function () {
            var $folder = $(this);
            var title = $folder.find('.folder_title_text span').text();
            if (title === self.folder_title) {
                var $icon_container = $folder.find('.NB-folder-icon');
                $icon_container.empty().removeClass('NB-has-custom-icon');
                if (is_custom) {
                    $icon_container.addClass('NB-has-custom-icon');
                    if (icon_url.indexOf('emoji:') === 0) {
                        $icon_container.append($.make('span', { className: 'NB-folder-emoji' }, icon_url.substring(6)));
                    } else if (has_color && is_preset_icon) {
                        // Use mask-image for colored preset icons
                        var $colored = $.make('span', { className: 'NB-folder-icon-colored' });
                        $colored.css({
                            'background-color': icon_color,
                            '-webkit-mask-image': 'url(' + icon_url + ')',
                            'mask-image': 'url(' + icon_url + ')'
                        });
                        $icon_container.append($colored);
                    } else {
                        $icon_container.append($.make('img', { className: 'feed_favicon', src: icon_url }));
                    }
                }
            }
        });

        // Update feedbar if viewing this folder
        if (NEWSBLUR.reader.active_folder && NEWSBLUR.reader.active_folder.get('folder_title') === this.folder_title) {
            var $feedbar = $('.NB-feedbar .NB-folder-icon');
            if ($feedbar.length) {
                $feedbar.empty();
                if (is_custom) {
                    if (icon_url.indexOf('emoji:') === 0) {
                        $feedbar.append($.make('span', { className: 'NB-folder-emoji' }, icon_url.substring(6)));
                    } else if (has_color && is_preset_icon) {
                        // Use mask-image for colored preset icons
                        var $colored = $.make('span', { className: 'NB-folder-icon-colored' });
                        $colored.css({
                            'background-color': icon_color,
                            '-webkit-mask-image': 'url(' + icon_url + ')',
                            'mask-image': 'url(' + icon_url + ')'
                        });
                        $feedbar.append($colored);
                    } else {
                        $feedbar.append($.make('img', { className: 'feed_favicon', src: icon_url }));
                    }
                }
            }
        }
    },

    handle_folder_icon_upload: function () {
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
        formData.append('folder_title', this.folder_title);
        formData.append('photo', file);

        $.ajax({
            url: '/reader/upload_folder_icon',
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
                    self.folder_icon = {
                        folder_title: self.folder_title,
                        icon_type: 'upload',
                        icon_data: response.icon_data,
                        icon_color: self.selected_icon_color || '#000000'
                    };
                    NEWSBLUR.assets.folder_icons[self.folder_title] = self.folder_icon;

                    // Show preview
                    $preview.empty().append(
                        $.make('img', { src: 'data:image/png;base64,' + response.icon_data }),
                        $.make('span', 'Uploaded!')
                    ).show();

                    self.update_header_icon();
                    self.refresh_folder_icon_everywhere();
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

    save_folder_icon: function () {
        var self = this;
        NEWSBLUR.assets.save_folder_icon(
            this.folder_title,
            this.selected_icon_type,
            this.selected_icon_data,
            this.selected_icon_color,
            function () {
                self.animate_saved();
                NEWSBLUR.reader.reload_feed_list();
            }
        );
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
            // Hide the clear link
            $('.NB-folder-icon-clear', self.$modal).hide();
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
    }

});

// Alias for folder icon editor functionality
NEWSBLUR.ReaderFolderIconEditor = function(options) {
    return new NEWSBLUR.ReaderFeedException(null, options);
};
