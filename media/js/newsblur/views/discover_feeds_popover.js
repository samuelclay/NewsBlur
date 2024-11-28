NEWSBLUR.DiscoverFeedsPopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-discover-popover",

    options: {
        'width': 604,
        'anchor': '.NB-feedbar-discover-container',
        'placement': 'bottom right',
        'offset': {
            top: 18,
            left: -110
        },
        'overlay_top': true,
        'popover_class': 'NB-filter-popover-container',
        'show_markscroll': true
    },

    events: {

    },

    initialize: function (options) {
        this.options = _.extend({}, this.options, options);
        this.options.offset.left = -1 * $(this.options.anchor).width() - 31;

        console.log("Opening discover popover", this.options, this.options.feed_id, this.$el, this.$el.closest(".popover-content"));

        this.$el.find(".popover-content").scroll(_.bind(this.check_scroll, this));

        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.model = NEWSBLUR.assets;

        this.discover_feeds_model = new NEWSBLUR.Collections.DiscoverFeeds();

        this.page = 1;
        this.has_more_results = true;
        this.is_loading = false;

        this.shown_feed_titles = new Set();

        if (!this.options.selected_folder_title) {
            var feed = NEWSBLUR.assets.get_feed(this.options.feed_id);
            if (feed) {
                var folders = feed.in_folders();
                if (folders.length > 0) {
                    this.options.selected_folder_title = folders[0];
                }
            } else {
                console.log("No feed found for discover popover", this.options.feed_id);
            }
        }

        this.fetch_data();
    },

    fetch_data: function () {
        var self = this;

        if (this.options.feed_id) {
            var feed = this.model.get_feed(this.options.feed_id);
            // this.discover_feeds_model.feed_ids = feed.get("similar_feeds"); // Let the server include this
            this.discover_feeds_model.similar_to_feed_id = feed.get("id");
        } else if (this.options.feed_ids) {
            this.discover_feeds_model.similar_to_feed_ids = this.options.feed_ids;
        }

        NEWSBLUR.ReaderPopover.prototype.render.call(this);

        this.show_loading();
        try {
            this.discover_feeds_model.fetch({
                type: this.discover_feeds_model.similar_to_feed_ids ? 'POST' : 'GET',
                data: { feed_ids: this.discover_feeds_model.similar_to_feed_ids },
                success: function () {
                    self.hide_loading();
                    self.render();
                },
                error: function () {
                    self.hide_loading();
                }
            });
        } catch (e) {
            console.log(["Error fetching discover feeds", e]);
            this.on_data_load_error();
        }
    },

    show_loading: function () {

        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, [
                    $.make('div', { className: 'NB-icon' }),
                    'Discover sites'
                ]),
                $.make('div', { className: 'NB-discover-loading' }, [
                    $.make('div', { className: 'NB-loading NB-active' })
                ])
            ])
        ]));
    },

    hide_loading: function () {
        this.$el.find(".NB-loading").html('');
    },

    on_data_load_error: function () {
        this.hide_loading();
        this.$el.find(".NB-discover-loading").html('<div class="error-message">Failed to load related sites</div>');
    },

    render: function () {
        var self = this;

        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, [
                    $.make('div', { className: 'NB-icon' }),
                    'Discover sites'
                ]),
                $.make('div', { className: 'NB-discover-feed-badges NB-story-pane-west' }, _.flatten(this.discover_feeds_model.map(function (discover_feed) {
                    var $story_titles = $.make('div', { className: 'NB-story-titles' });
                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                        el: $story_titles,
                        collection: discover_feed.get("stories"),
                        $story_titles: $story_titles,
                        override_layout: 'split',
                        on_discover_feed: discover_feed,
                        in_popover: self
                    });
                    return $.make('div', { className: 'NB-discover-feed-badge' }, [
                        new NEWSBLUR.Views.FeedBadge({
                            model: discover_feed.get("feed"),
                            show_folders: true,
                            selected_folder_title: self.options.selected_folder_title,
                            in_popover: self,
                            load_feed_after_add: false
                        }),
                        story_titles_view.render().el
                    ]);
                }))),
                $.make('div', { className: 'NB-loading-container' })
            ])
        ]));

        this.check_height();

        this.throttled_check_scroll = _.throttle(this.check_scroll, 100);
        this.$el.closest(".popover-content").scroll(_.bind(this.throttled_check_scroll, this));

        this.shown_feed_titles.clear();
        this.discover_feeds_model.each(function (discover_feed) {
            this.shown_feed_titles.add(discover_feed.get("feed").feed_title);
        }, this);

        return this;
    },

    check_scroll: function () {
        if (this.is_loading || !this.has_more_results) return;

        var $container = this.$el.closest(".popover-content");
        var containerHeight = $container.height();
        var scrollTop = $container.scrollTop();
        var scrollHeight = $container[0].scrollHeight;

        if (scrollHeight - (scrollTop + containerHeight) < 200) {
            this.load_more_sites();
        }
    },

    load_more_sites: function () {
        if (this.is_loading || !this.has_more_results) return;

        this.is_loading = true;
        this.show_additional_loading();

        this.page += 1;
        var self = this;
        console.log("Loading more sites on page: ", this.page);
        this.discover_feeds_model.fetch({
            type: this.discover_feeds_model.similar_to_feed_ids ? 'POST' : 'GET',
            data: {
                feed_ids: this.discover_feeds_model.similar_to_feed_ids,
                page: this.page
            },
            success: function (model, response) {
                console.log("Successfully loaded more sites on page: ", self.page, response);
                self.render_additional_sites(response.discover_feeds);
                if (self.page > 10) {
                    self.has_more_results = false;
                } else {
                    self.has_more_results = response.discover_feeds && _.keys(response.discover_feeds).length > 0;
                }
                self.is_loading = false;
                self.hide_additional_loading();
            },
            error: function () {
                self.is_loading = false;
                self.hide_additional_loading();
            }
        });
    },

    render_additional_sites: function (new_sites) {
        var self = this;
        var $feed_badges = this.$('.NB-discover-feed-badges');

        _.each(new_sites, function (discover_feed, feed_id) {
            var feed_title = discover_feed.feed.feed_title;

            if (self.shown_feed_titles.has(feed_title)) {
                console.log("Already shown feed: ", feed_title);
                return;
            }
            self.shown_feed_titles.add(feed_title);

            var $story_titles = $.make('div', { className: 'NB-story-titles' });
            var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                el: $story_titles,
                collection: new NEWSBLUR.Collections.Stories(discover_feed.stories),
                $story_titles: $story_titles,
                override_layout: 'split',
                on_discover_feed: new NEWSBLUR.Models.DiscoverFeed({
                    feed: discover_feed.feed,
                    stories: discover_feed.stories
                }),
                in_popover: self
            });

            var $feed_badge = $.make('div', { className: 'NB-discover-feed-badge' }, [
                new NEWSBLUR.Views.FeedBadge({
                    model: new NEWSBLUR.Models.Feed(discover_feed.feed),
                    show_folders: true,
                    selected_folder_title: self.options.selected_folder_title,
                    in_popover: self,
                    load_feed_after_add: false
                }),
                story_titles_view.render().el
            ]);

            $feed_badges.append($feed_badge);
        });

        this.check_height();
    },

    show_additional_loading: function () {
        this.hide_additional_loading();

        var $endline = $.make('div', { className: "NB-end-line NB-short" });
        $endline.css({ 'background': '#FFF' });
        this.$(".NB-loading-container").append($endline);
        clearInterval(this.loading_interval);

        $endline.animate({ 'backgroundColor': '#E1EBFF' }, { 'duration': 550, 'easing': 'easeInQuad' })
            .animate({ 'backgroundColor': '#5C89C9' }, { 'duration': 1550, 'easing': 'easeOutQuad' })
            .animate({ 'backgroundColor': '#E1EBFF' }, 1050);
        _.delay(_.bind(function () {
            this.loading_interval = setInterval(function () {
                $endline.animate({ 'backgroundColor': '#5C89C9' }, { 'duration': 650 })
                    .animate({ 'backgroundColor': '#E1EBFF' }, 1050);
            }, 1700);
        }, this), (550 + 1550 + 1050) - 1700);
    },

    hide_additional_loading: function () {
        clearInterval(this.loading_interval);
        this.$(".NB-end-line").remove();
    },

    // ==========
    // = Events =
    // ==========



});
