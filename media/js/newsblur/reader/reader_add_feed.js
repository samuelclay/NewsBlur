NEWSBLUR.ReaderAddFeed = NEWSBLUR.ReaderPopover.extend({

    className: "NB-add-popover",

    options: {
        'width': 608,
        'popover_class': 'NB-add-popover-container',
        'anchor': function () {
            return NEWSBLUR.reader.$s.$add_button;
        },
        'placement': 'top -left',
        offset: {
            top: 6,
            left: 3
        },
        'onOpen': _.bind(function () {
            this.focus_add_feed();
        }, this)
    },

    events: {
        "click .NB-modal-cancel": "close",
        "click .NB-add-url-submit": "save_add_url",
        "click .NB-add-folder-icon": "open_add_folder",
        "click .NB-add-folder-submit": "save_add_folder",
        "click .NB-add-import-button": "close_and_open_import",
        "click .NB-add-discover-trending": "close_and_open_trending",
        "mouseenter .NB-add-discover-popular": "show_popular_flyout",
        "mouseleave .NB-add-discover-popular": "hide_popular_flyout",
        "click .NB-add-discover-popular-category": "close_and_open_popular_category",
        "click .NB-add-discover-source": "close_and_open_discover_tab",
        "focus .NB-add-url": "handle_focus_add_site",
        "blur .NB-add-url": "handle_blur_add_site",
        "change .NB-folders": "update_folder_placeholder"
    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this);
        this.model = NEWSBLUR.assets;
        this.render();
        this.handle_keystrokes();
        this.setup_autocomplete();

        // this.setup_chosen();
        this.focus_add_feed();
    },

    on_show: function () {
        this.options.onOpen();
    },

    on_hide: function () {

    },

    render: function () {
        var self = this;

        NEWSBLUR.ReaderPopover.prototype.render.call(this);

        this.$el.html($.make('div', { className: 'NB-add' }, [
            $.make('div', { className: 'NB-add-form' }, [
                $.make('div', { className: 'NB-fieldset NB-modal-submit' }, [
                    $.make('div', { className: 'NB-add-header' }, [
                        $.make('span', { className: 'NB-add-header-icon' }, '+'),
                        $.make('span', 'Add any site or feed'),
                        $.make('div', { className: 'NB-add-folder-row' }, [
                            $.make('span', { className: 'NB-add-folder-label' }, 'in'),
                            NEWSBLUR.utils.make_folders(this.options.folder_title),
                            $.make('div', { className: 'NB-add-folder-icon', title: "New folder", role: "button" })
                        ])
                    ]),
                    $.make('div', { className: 'NB-add-input-row' }, [
                        $.make('input', { type: 'text', id: 'NB-add-url', className: 'NB-add-url', name: 'url', value: self.options.url, placeholder: 'Site URL or search by name...' }),
                        $.make('div', { className: 'NB-loading' }),
                        $.make('div', { className: 'NB-add-url-submit' }, 'Add site')
                    ]),
                    $.make('div', { className: "NB-add-folder NB-hidden" }, [
                        $.make('div', { className: 'NB-add-folder-input-row' }, [
                            $.make('input', { type: 'text', id: 'NB-add-folder', className: 'NB-add-folder-input', name: 'new_folder_name', placeholder: "New folder name..." }),
                            $.make('div', { className: 'NB-loading' }),
                            $.make('div', { className: 'NB-add-folder-submit' }, 'Create')
                        ])
                    ]),
                    $.make('div', { className: 'NB-group NB-error' }, [
                        $.make('div', { className: 'NB-error-message' })
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset NB-add-discover-section' }, [
                    $.make('div', { className: 'NB-add-discover-divider' }, [
                        $.make('span', 'Discover more to read')
                    ]),
                    $.make('div', { className: 'NB-add-discover-sources' }, [
                        $.make('div', { className: 'NB-add-discover-source', 'data-tab': 'youtube' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/lucide/youtube.svg' }),
                            $.make('span', 'YouTube')
                        ]),
                        $.make('div', { className: 'NB-add-discover-source', 'data-tab': 'reddit' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/reader/reddit.png' }),
                            $.make('span', 'Reddit')
                        ]),
                        $.make('div', { className: 'NB-add-discover-source', 'data-tab': 'newsletters' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/lucide/mail.svg' }),
                            $.make('span', 'Newsletters')
                        ]),
                        $.make('div', { className: 'NB-add-discover-source', 'data-tab': 'podcasts' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/lucide/podcast.svg' }),
                            $.make('span', 'Podcasts')
                        ]),
                        $.make('div', { className: 'NB-add-discover-source', 'data-tab': 'google-news' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/lucide/newspaper.svg', className: 'NB-mono' }),
                            $.make('span', 'Google News')
                        ])
                    ]),
                    $.make('div', { className: 'NB-add-discover-buttons' }, [
                        $.make('div', { className: 'NB-add-discover-btn NB-add-discover-trending' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/nouns/pulse.svg' }),
                            $.make('span', 'Trending')
                        ]),
                        $.make('div', { className: 'NB-add-discover-btn NB-add-discover-popular' }, [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/heroicons-solid/fire.svg' }),
                            $.make('span', 'Popular'),
                            $.make('span', { className: 'NB-add-discover-popular-arrow' }, '\u25BE'),
                            $.make('div', { className: 'NB-add-discover-popular-flyout NB-hidden' }, [
                                $.make('div', { className: 'NB-add-discover-popular-flyout-inner' })
                            ])
                        ])
                    ])
                ]),
                $.make('div', { className: 'NB-fieldset NB-anonymous-ok NB-modal-submit NB-hidden' }, [
                    $.make('h5', [
                        'Import feeds'
                    ]),
                    $.make('div', { className: 'NB-fieldset-fields' }, [
                        $.make('div', { className: 'NB-add-import-button NB-modal-submit-green NB-modal-submit-button' }, [
                            'Import from Google Reader or upload OPML',
                            $.make('img', { className: 'NB-add-google-reader-arrow', src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/silk/arrow_right.png' })
                        ]),
                        $.make('div', { className: 'NB-add-danger' }, (NEWSBLUR.Globals.is_authenticated && _.size(this.model.feeds) > 0 && [
                            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'img/icons/silk/server_go.png' }),
                            'This will erase all existing feeds and folders.'
                        ]))
                    ])
                ])
            ])
        ]));

        if (NEWSBLUR.Globals.is_anonymous) {
            this.$el.addClass('NB-signed-out');
        }

        return this;
    },

    focus_add_feed: function () {
        var $add = this.options.init_folder ?
            this.$('.NB-add-folder-input') :
            this.$('.NB-add-url');
        if (!NEWSBLUR.Globals.is_anonymous) {
            _.delay(_.bind(function () {
                if (this.options.init_folder) {
                    this.open_add_folder();
                }
                $add.focus();
            }, this), 200);
        }
    },

    setup_autocomplete: function () {
        var self = this;
        var $add = this.$('.NB-add-url');

        $add.autocomplete({
            minLength: 1,
            appendTo: ".NB-add-form",
            source: function (request, response) {
                $add.addClass('NB-autocomplete-loading');
                $.getJSON('/discover/autocomplete', { term: request.term })
                    .done(function (data) {
                        response(data.slice(0, 10));
                    })
                    .fail(function () {
                        response([]);
                    })
                    .always(function () {
                        $add.removeClass('NB-autocomplete-loading');
                    });
            },
            position: {
                my: "left bottom",
                at: "left top",
                collision: "none"
            },
            select: function (e, ui) {
                $add.val(ui.item.value);
                self.save_add_url();
                return false;
            },
            search: function (e, ui) {
            },
            open: function (e, ui) {
                if (!$add.is(":focus")) {
                    e.preventDefault();
                    $add.autocomplete('close');
                    return false;
                }
            },
            close: function (e, ui) {
            },
            change: function (e, ui) {
            }
        }).data("ui-autocomplete")._renderItem = function (ul, item) {
            var feed = new NEWSBLUR.Models.Feed(item);
            var freshness = self.make_freshness_indicator(item.last_story_date);
            var num_subscribers = Math.max(0, item.num_subscribers);
            var subscriber_text = num_subscribers === 1 ? '1 subscriber' : Inflector.commas(num_subscribers) + ' subscribers';
            return $.make('li', [
                $.make('a', { className: 'NB-autocomplete-item' }, [
                    $.favicon_el(feed, {
                        image_class: 'NB-add-autocomplete-favicon',
                        emoji_class: 'NB-add-autocomplete-favicon NB-feed-emoji',
                        colored_class: 'NB-add-autocomplete-favicon NB-feed-icon-colored'
                    }),
                    $.make('div', { className: 'NB-autocomplete-content' }, [
                        $.make('div', { className: 'NB-autocomplete-top-row' }, [
                            $.make('div', { className: 'NB-add-autocomplete-title' }, item.label),
                            $.make('div', { className: 'NB-add-autocomplete-subscribers' }, subscriber_text)
                        ]),
                        $.make('div', { className: 'NB-autocomplete-bottom-row' }, [
                            $.make('div', { className: 'NB-add-autocomplete-address' }, item.value),
                            freshness
                        ])
                    ])
                ])
            ]).data("ui-autocomplete-item", item).prependTo(ul);
        };
        $add.data("ui-autocomplete")._resizeMenu = function () {
            var ul = this.menu.element;
            var $row = self.$('.NB-add-input-row');
            ul.outerWidth($row.length ? $row.outerWidth() : this.element.outerWidth());
        };
    },

    handle_focus_add_site: function () {
        var $add = this.$('.NB-add-url');
        $add.autocomplete('search');
    },

    handle_blur_add_site: function () {
        var $add = this.$('.NB-add-url');
        $add.autocomplete('close');
    },

    setup_chosen: function () {
        var $select = this.$('select');
        $select.chosen();
    },

    handle_keystrokes: function () {
        var self = this;

        this.$('.NB-add-url').bind('keyup', 'return', function (e) {
            e.preventDefault();
            self.save_add_url();
        });

        this.$('.NB-add-folder-input').bind('keyup', 'return', function (e) {
            e.preventDefault();
            self.save_add_folder();
        });
    },

    close_and_open_import: function () {
        this.close(function () {
            NEWSBLUR.reader.open_intro_modal({
                'page_number': 2,
                'force_import': true
            });
        });
    },

    close_and_open_trending: function () {
        this.close(function () {
            NEWSBLUR.reader.open_add_site({ tab: 'trending' });
        });
    },

    show_popular_flyout: function () {
        var $flyout = this.$('.NB-add-discover-popular-flyout');
        var $inner = this.$('.NB-add-discover-popular-flyout-inner');
        this.render_popular_categories($inner);
        $flyout.removeClass('NB-hidden');
    },

    hide_popular_flyout: function () {
        var $flyout = this.$('.NB-add-discover-popular-flyout');
        $flyout.addClass('NB-hidden');
    },

    render_popular_categories: function ($container) {
        if (this._popular_categories) {
            if ($container.children().length > 0) return;
            _.each(this._popular_categories, function (cat, index) {
                var is_all = cat.id === 'all';
                var class_name = 'NB-add-discover-popular-category';
                if (is_all) class_name += ' NB-category-all';
                $container.append($.make('div', {
                    className: class_name,
                    'data-category': cat.id
                }, [
                    $.make('span', { className: 'NB-add-discover-popular-category-name' }, cat.name),
                    $.make('span', { className: 'NB-add-discover-popular-category-count' }, cat.count ? Inflector.pluralize(' site', cat.count, true) : '')
                ]));
                if (is_all) {
                    $container.append($.make('div', { className: 'NB-add-discover-popular-separator' }));
                }
            });
            return;
        }

        $container.html($.make('div', { className: 'NB-add-discover-popular-loading' }, 'Loading...'));

        var self = this;
        $.ajax({
            url: '/discover/popular_feeds',
            data: { type: 'all', limit: 1 },
            success: function (data) {
                var categories = [];
                if (data && data.grouped_categories) {
                    categories = _.map(data.grouped_categories, function (cat) {
                        return { id: cat.name, name: cat.name, count: cat.feed_count || 0 };
                    });
                }
                categories.unshift({ id: 'all', name: 'All Categories', count: 0 });
                self._popular_categories = categories;
                $container.empty();
                self.render_popular_categories($container);
            },
            error: function () {
                self._popular_categories = [
                    { id: 'all', name: 'All Categories', count: 0 },
                    { id: 'science', name: 'Science', count: 0 },
                    { id: 'technology', name: 'Technology', count: 0 },
                    { id: 'gaming', name: 'Gaming', count: 0 },
                    { id: 'education', name: 'Education', count: 0 }
                ];
                $container.empty();
                self.render_popular_categories($container);
            }
        });
    },

    close_and_open_popular_category: function (e) {
        e.stopPropagation();
        var category = $(e.currentTarget).data('category');
        this.close(function () {
            NEWSBLUR.reader.open_add_site({ tab: 'popular', category: category });
        });
    },

    close_and_open_discover_tab: function (e) {
        var tab = $(e.currentTarget).data('tab');
        this.close(function () {
            NEWSBLUR.reader.open_add_site({ tab: tab });
        });
    },

    make_freshness_indicator: function (last_story_date) {
        if (!last_story_date) {
            return $.make('div', { className: 'NB-autocomplete-freshness NB-freshness-none' }, [
                $.make('span', { className: 'NB-freshness-dot' }),
                $.make('span', { className: 'NB-freshness-label' }, 'No stories')
            ]);
        }

        var last_date = new Date(last_story_date);
        if (isNaN(last_date.getTime())) return null;

        var now = new Date();
        var days_ago = Math.floor((now - last_date) / (1000 * 60 * 60 * 24));
        var freshness_class = 'NB-autocomplete-freshness';
        var label;

        if (days_ago < 365) {
            freshness_class += ' NB-freshness-active';
            if (days_ago < 1) {
                label = 'Updated today';
            } else if (days_ago < 7) {
                label = days_ago + 'd ago';
            } else if (days_ago < 30) {
                label = Math.floor(days_ago / 7) + 'w ago';
            } else {
                label = Math.floor(days_ago / 30) + 'mo ago';
            }
        } else {
            freshness_class += ' NB-freshness-stale';
            label = 'Stale ' + last_date.toLocaleDateString(undefined, { month: 'short', year: 'numeric' });
        }

        return $.make('div', { className: freshness_class }, [
            $.make('span', { className: 'NB-freshness-dot' }),
            $.make('span', { className: 'NB-freshness-label' }, label)
        ]);
    },

    // ===========
    // = Actions =
    // ===========

    save_add_url: function () {
        var $submit = this.$('.NB-add-url-submit');
        var $error = this.$('.NB-error');
        var $loading = this.$('.NB-add-site .NB-loading');

        var url = this.$('.NB-add-url').val();
        var folder = this.$('.NB-folders').val();

        // Check feed limit before adding
        var add_limit = NEWSBLUR.Globals.add_feed_limit;
        var active_feeds = NEWSBLUR.assets.feeds.active().length;
        if (add_limit && active_feeds >= add_limit) {
            this.error({
                message: "You've reached your limit of " + Inflector.commas(add_limit) +
                    " sites. Mute some sites or upgrade your account to add more."
            });
            return;
        }

        $error.slideUp(300);
        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').text('Adding site...');

        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        this.model.save_add_url(url, folder, $.rescope(this.post_save_add_url, this), $.rescope(this.error, this));
    },

    post_save_add_url: function (e, data) {
        NEWSBLUR.log(['Data', data]);
        var $submit = this.$('.NB-add-url-submit');
        var $loading = this.$('.NB-add-site .NB-loading');
        $loading.removeClass('NB-active');
        NEWSBLUR.reader.flags['reloading_feeds'] = false;

        if (data.code > 0) {
            NEWSBLUR.assets.load_feeds(function () {
                if (data.feed) {
                    NEWSBLUR.reader.open_feed(data.feed.id);
                }
                // Show growth prompt after feed is added (if eligible)
                if (NEWSBLUR.growth_prompts) {
                    NEWSBLUR.growth_prompts.on_feed_added();
                }
            });
            NEWSBLUR.reader.load_recommended_feed();
            NEWSBLUR.reader.handle_mouse_indicator_hover();
            $submit.text('Added!');
            this.close();
            this.model.preference('has_setup_feeds', true);
            NEWSBLUR.reader.check_hide_getting_started();
        } else {
            var url = this.$('.NB-add-url').val();
            this.handle_add_failure(url, data);
            $submit.removeClass('NB-disabled');
        }
    },

    handle_add_failure: function (input, data) {
        // Feed limit errors should always show inline
        var add_limit = NEWSBLUR.Globals.add_feed_limit;
        var active_feeds = NEWSBLUR.assets.feeds.active().length;
        if (add_limit && active_feeds >= add_limit) {
            this.error(data);
            return;
        }

        input = (input || '').trim();
        if (input && input.indexOf('.') !== -1 && input.indexOf(' ') === -1) {
            // Looks like a URL - redirect to Web Feed tab
            this.close(function () {
                NEWSBLUR.reader.open_add_site({ tab: 'web-feed', initial_url: input });
            });
        } else if (input) {
            // Looks like a search term - redirect to Search tab
            this.close(function () {
                NEWSBLUR.reader.open_add_site({ tab: 'search', initial_query: input });
            });
        } else {
            this.error(data);
        }
    },

    error: function (data) {
        var $submit = this.$('.NB-add-url-submit');
        var $error = this.$('.NB-error');

        $(".NB-error-message", $error).text(data.message || "Oh no, there was a problem grabbing that URL and there's no good explanation for what happened.");
        $error.slideDown(300);
        $submit.text('Add site');
        NEWSBLUR.reader.flags['reloading_feeds'] = false;
    },

    update_folder_placeholder: function () {
        var parent_folder = this.$('.NB-folders option:selected').text().trim() || 'Top Level';
        this.$('.NB-add-folder-input').attr('placeholder', 'New folder under ' + parent_folder + '...');
    },

    open_add_folder: function () {
        var $folder = this.$(".NB-add-folder");
        var $icon = this.$(".NB-add-folder-icon");

        if (this._open_folder) {
            $folder.slideUp(300);
            $icon.removeClass('NB-active');
            this._open_folder = false;
        } else {
            this._open_folder = true;
            $icon.addClass('NB-active');
            this.update_folder_placeholder();
            $folder.slideDown(300);
        }
    },

    save_add_folder: function () {
        var $submit = this.$('.NB-add-folder-submit');
        var $error = this.$('.NB-error');
        var $loading = this.$('.NB-add-folder .NB-loading');

        var folder = $('.NB-add-folder-input').val();
        var parent_folder = this.$('.NB-folders').val();

        $error.slideUp(300);
        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').text('Adding site...');

        this.model.save_add_folder(folder, parent_folder, $.rescope(this.post_save_add_folder, this));
    },

    post_save_add_folder: function (e, data) {
        var $submit = this.$('.NB-add-folder-submit');
        var $error = this.$('.NB-error');
        var $loading = this.$('.NB-add-folder .NB-loading');
        var $folder = $('.NB-add-folder-input');
        $loading.removeClass('NB-active');
        $submit.removeClass('NB-disabled');

        if (data.code > 0) {
            $submit.text('Added!');
            NEWSBLUR.assets.load_feeds(_.bind(function () {
                var $folders = NEWSBLUR.utils.make_folders($folder.val());
                this.$(".NB-folders").replaceWith($folders);
                this.open_add_folder();
                $submit.text('Add Folder');
                $folder.val('');
                this.$('.NB-add-url').focus();
            }, this));
        } else {
            $(".NB-error-message", $error).text(data.message);
            $error.slideDown(300);
            $submit.text('Add Folder');
        }
    }

});
