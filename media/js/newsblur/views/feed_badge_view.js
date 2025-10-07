NEWSBLUR.Views.FeedBadge = Backbone.View.extend({

    className: "NB-feed-badge",

    events: {
        "click .NB-badge-action-try": "try_feed",
        "click .NB-badge-action-add": "add_feed",
        "click .NB-icon-stats": "open_stats"
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

        this.$el.html($.make('div', { className: 'NB-feed-badge-inner' }, [
            $.make('div', { className: "NB-feed-badge-title" }, [
                $.make('img', { src: $.favicon(this.model) }),
                this.model.get('feed_title')
            ]),
            $.make('div', { className: "NB-feed-badge-tagline" }, this.model.get('tagline')),
            $.make('div', { className: "NB-feed-badge-stats" }, [
                $.make('div', { className: "NB-icon NB-icon-stats" }),
                $.make('b', Inflector.commas(this.model.get('num_subscribers'))),
                Inflector.pluralize('subscriber', this.model.get('num_subscribers')),
                $.make('br'),
                $.make('b', Inflector.commas(this.model.get('average_stories_per_month'))),
                Inflector.pluralize('story', this.model.get('average_stories_per_month')),
                ' per month'
            ]),
            (subscribed && $.make('div', { className: 'NB-subscribed' }, "Subscribed")),
            (!subscribed && $.make('div', { className: 'NB-feed-badge-actions' }, [
                (!this.options.hide_try_button && $.make('div', {
                    className: 'NB-badge-action-try NB-modal-submit-button NB-modal-submit-green'
                }, [
                    $.make('span', 'Try')
                ])),
                $.make('div', {
                    className: 'NB-badge-action-add NB-modal-submit-button NB-modal-submit-grey '
                }, 'Add'),
                (this.options.show_folders && $.make('div', { className: 'NB-badge-folders' }, [
                    NEWSBLUR.utils.make_folders(this.options.selected_folder_title)
                ])),
                $.make("div", { className: "NB-loading" }),
                $.make('div', { className: 'NB-error' })
            ]))
        ]));

        return this;
    },

    try_feed: function () {
        NEWSBLUR.reader.load_feed_in_tryfeed_view(this.model.id);
        if (this.options.in_popover) {
            this.options.in_popover.close();
        }
    },

    add_feed: function () {
        if (this.options.in_popover) {
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
        var folder = this.$('.NB-folders').val();

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
    }

});
