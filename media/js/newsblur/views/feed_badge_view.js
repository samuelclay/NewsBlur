NEWSBLUR.Views.FeedBadge = Backbone.View.extend({

    className: "NB-feed-badge",

    events: {
        "click .NB-badge-action-try": "try_feed",
        "click .NB-badge-action-add": "add_feed",
        "click .NB-badge-action-stats": "open_stats",
        "click .NB-badge-action-open": "open_feed"
    },

    options: {
        load_feed_after_add: true
    },

    constructor: function (options) {
        Backbone.View.call(this, options);

        this.render();

        return this.el;
    },

    initialize: function () {
        _.bindAll(this, 'render');
        this.model.bind('change', this.render);
    },

    render: function () {
        var subscribed = NEWSBLUR.assets.get_feed(this.model.id);
        var in_add_site = this.options.in_add_site_view;
        var actions_in_header = in_add_site && !this.options.in_popover;

        // Build folder selector based on context
        var $folder_selector = null;
        if (this.options.show_folders) {
            if (in_add_site) {
                // Use grid-style folder selector in add site view
                var $select = $(NEWSBLUR.utils.make_folders(this.options.selected_folder_title))
                    .addClass('NB-add-site-folder-select');
                $select.append($.make('option', { value: '__new__' }, '+ New Folder...'));
                $folder_selector = $select;
            } else {
                $folder_selector = $.make('div', { className: 'NB-badge-folders' }, [
                    NEWSBLUR.utils.make_folders(this.options.selected_folder_title)
                ]);
            }
        }

        // Add extra class for add site view styling
        var actions_class = 'NB-feed-badge-actions';
        if (in_add_site) {
            actions_class += ' NB-feed-badge-actions-add-site';
        }

        // Build meta string like grid view
        var meta_parts = [];
        var num_subscribers = Math.max(0, this.model.get('num_subscribers') || 0);
        var stories_per_month = this.model.get('average_stories_per_month');
        if (num_subscribers) {
            meta_parts.push(Inflector.commas(num_subscribers) + ' ' + Inflector.pluralize('subscriber', num_subscribers));
        }
        if (stories_per_month) {
            meta_parts.push(Inflector.commas(stories_per_month) + ' ' + Inflector.pluralize('story', stories_per_month) + '/month');
        }

        // Build freshness indicator if in add site view
        var $freshness = null;
        if (in_add_site && in_add_site.make_freshness_indicator) {
            $freshness = in_add_site.make_freshness_indicator(
                this.model.get('last_story_date'), { show_empty: true }
            );
        }

        var $stats_btn = $.make('div', {
            className: 'NB-badge-action-stats NB-modal-submit-button NB-modal-submit-grey'
        }, [
            $.make('img', { src: NEWSBLUR.Globals['MEDIA_URL'] + 'embed/icons/nouns/dialog-statistics.svg', className: 'NB-badge-stats-icon' }),
            'Stats'
        ]);

        var $actions;
        if (subscribed && actions_in_header) {
            // Two-row layout: Subscribed badge on top, Stats+Open below
            $actions = $.make('div', { className: 'NB-feed-badge-subscribed-actions NB-feed-badge-actions-add-site' }, [
                $.make('div', { className: 'NB-subscribed-badge' }, [
                    $.make('span', { className: 'NB-subscribed-badge-check' }, '\u2713'),
                    ' Subscribed'
                ]),
                $.make('div', { className: 'NB-badge-actions-row' }, [
                    $stats_btn,
                    $.make('div', { className: 'NB-badge-action-open NB-modal-submit-button NB-modal-submit-green' }, 'Open')
                ])
            ]);
        } else if (subscribed) {
            $actions = $.make('div', { className: 'NB-feed-badge-subscribed-actions' }, [
                $.make('div', { className: 'NB-subscribed-indicator' }, 'Subscribed'),
                $stats_btn,
                $.make('div', { className: 'NB-badge-action-open NB-modal-submit-button NB-modal-submit-green' }, 'Open')
            ]);
        } else if (actions_in_header) {
            // Two-row layout for add site list view: Try+Stats on top, folder+Add below
            $actions = $.make('div', { className: actions_class }, [
                $.make('div', { className: 'NB-badge-actions-row' }, [
                    (!this.options.hide_try_button && $.make('div', {
                        className: 'NB-badge-action-try NB-modal-submit-button NB-modal-submit-green'
                    }, [
                        $.make('span', 'Try')
                    ])),
                    $stats_btn
                ].filter(Boolean)),
                $.make('div', { className: 'NB-badge-folder-add-group' }, [
                    $folder_selector,
                    $.make('div', {
                        className: 'NB-badge-action-add NB-modal-submit-button NB-modal-submit-green'
                    }, 'Add')
                ]),
                $.make("div", { className: "NB-loading" }),
                $.make('div', { className: 'NB-error' })
            ]);
        } else {
            $actions = $.make('div', { className: actions_class }, [
                (!this.options.hide_try_button && $.make('div', {
                    className: 'NB-badge-action-try NB-modal-submit-button NB-modal-submit-green'
                }, [
                    $.make('span', 'Try')
                ])),
                $stats_btn,
                $.make('div', { className: 'NB-badge-folder-add-group' }, [
                    $folder_selector,
                    $.make('div', {
                        className: 'NB-badge-action-add NB-modal-submit-button NB-modal-submit-green'
                    }, 'Add')
                ]),
                $.make("div", { className: "NB-loading" }),
                $.make('div', { className: 'NB-error' })
            ]);
        }

        this.$el.html($.make('div', { className: 'NB-feed-badge-inner' }, [
            $.make('div', { className: "NB-feed-badge-header" }, [
                $.make('div', { className: "NB-feed-badge-icon" }, [
                    $.favicon_el(this.model, { image_class: '', emoji_class: 'NB-feed-emoji', colored_class: 'NB-feed-icon-colored' })
                ]),
                $.make('div', { className: "NB-feed-badge-info" }, [
                    $.make('div', { className: "NB-feed-badge-title" }, this.model.get('feed_title')),
                    $.make('div', { className: "NB-feed-badge-meta" }, meta_parts.join(' • ')),
                    $freshness
                ].filter(Boolean)),
                (actions_in_header && $actions)
            ].filter(Boolean)),
            $.make('div', { className: "NB-feed-badge-tagline" }, this.model.get('tagline')),
            (!actions_in_header && $actions)
        ].filter(Boolean)));

        return this;
    },

    try_feed: function () {
        NEWSBLUR.reader.load_feed_in_tryfeed_view(this.model.id);
        if (this.options.in_popover) {
            this.options.in_popover.close();
        }
    },

    add_feed: function () {
        if (this.options.in_popover || this.options.in_add_site_view) {
            this.save_add_url();
        } else {
            NEWSBLUR.reader.open_add_feed_modal({ url: this.model.get('feed_address') });
        }
    },

    save_add_url: function () {
        var $submit = this.$('.NB-badge-action-add');
        var $error = this.$('.NB-error');
        var $loading = this.$('.NB-loading');

        var url = this.model.get('feed_address');
        // Support both original .NB-folders and grid-style .NB-add-site-folder-select
        var $folder_select = this.$('.NB-add-site-folder-select');
        if (!$folder_select.length) {
            $folder_select = this.$('.NB-folders');
        }
        var folder = $folder_select.val() || '';

        $error.slideUp(300);
        $loading.addClass('NB-active');
        $submit.addClass('NB-disabled').text('Adding...');

        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        NEWSBLUR.assets.save_add_url(url, folder, _.bind(this.post_save_add_url, this), _.bind(this.error, this));
    },

    post_save_add_url: function (data) {
        NEWSBLUR.log(['Post save data', data]);
        var self = this;
        var $submit = this.$('.NB-badge-action-add');
        var $loading = this.$('.NB-loading');
        $loading.removeClass('NB-active');
        NEWSBLUR.reader.flags['reloading_feeds'] = false;

        if (data && data.code > 0) {
            NEWSBLUR.assets.load_feeds(function () {
                if (self.options.load_feed_after_add) {
                    if (data.feed) {
                        NEWSBLUR.reader.open_feed(data.feed.id);
                    }
                }
            });
            NEWSBLUR.reader.handle_mouse_indicator_hover();

            $submit.text('Subscribed!');
        } else {
            this.error(data);
            $submit.removeClass('NB-disabled');
        }
    },

    error: function (data) {
        var $submit = this.$('.NB-badge-action-add');
        var $error = this.$('.NB-error');

        $error.text(data.message || "Oh no, there was a problem grabbing that URL and there's no good explanation for what happened.");
        $error.slideDown(300);
        $submit.text('Add');
        NEWSBLUR.reader.flags['reloading_feeds'] = false;
    },

    open_stats: function () {
        var load_stats = _.bind(function () {
            NEWSBLUR.assets.load_canonical_feed(this.model.id, _.bind(function () {
                NEWSBLUR.reader.open_feed_statistics_modal(this.model.id);
            }, this));
        }, this);

        if (this.options.in_popover) {
            this.options.in_popover.close(load_stats);
        } else {
            load_stats();
        }
    },

    open_feed: function () {
        NEWSBLUR.reader.open_feed(this.model.id);
    }

});
