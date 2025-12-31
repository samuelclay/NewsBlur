NEWSBLUR.Views.TrendingSitesView = Backbone.View.extend({

    className: "NB-trending-sites-view",

    events: {
        "change .NB-trending-time-selector": "change_time_window"
    },

    initialize: function (options) {
        this.options = options || {};
        this.model = NEWSBLUR.assets;
        this.trending_feeds_model = new NEWSBLUR.Collections.TrendingFeeds();

        this.page = 1;
        this.days = 7;
        this.has_more_results = true;
        this.is_loading = false;
        this.shown_feed_titles = new Set();

        this.fetch_data();
    },

    fetch_data: function () {
        var self = this;

        this.show_loading();
        this.trending_feeds_model.fetch({
            data: { page: this.page, days: this.days },
            success: function () {
                self.has_more_results = self.trending_feeds_model.has_more;
                self.hide_loading();
                self.render();
            },
            error: function () {
                self.hide_loading();
                self.on_data_load_error();
            }
        });
    },

    show_loading: function () {
        this.$el.html($.make('div', { className: 'NB-trending-container' }, [
            $.make('div', { className: 'NB-trending-loading' }, [
                $.make('div', { className: 'NB-loading NB-active' })
            ])
        ]));
    },

    hide_loading: function () {
        this.$el.find(".NB-loading").removeClass('NB-active').html('');
    },

    on_data_load_error: function () {
        this.hide_loading();
        this.$el.find(".NB-trending-loading").html(
            $.make('div', { className: 'NB-trending-error' }, 'Failed to load trending sites')
        );
    },

    render: function () {
        var self = this;
        var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');

        this.$el.html($.make('div', { className: 'NB-trending-container' }, [
            $.make('div', { className: 'NB-trending-feed-badges NB-story-pane-' + pane_anchor },
                _.flatten(this.trending_feeds_model.map(function (trending_feed) {
                    var $story_titles = $.make('div', { className: 'NB-story-titles' });
                    var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                        el: $story_titles,
                        collection: trending_feed.get("stories"),
                        $story_titles: $story_titles,
                        override_layout: 'split',
                        pane_anchor: pane_anchor,
                        on_trending_feed: trending_feed,
                        in_trending_view: self
                    });
                    return $.make('div', { className: 'NB-trending-feed-badge' }, [
                        new NEWSBLUR.Views.FeedBadge({
                            model: trending_feed.get("feed"),
                            show_folders: true,
                            in_trending_view: self,
                            load_feed_after_add: false
                        }),
                        story_titles_view.render().el
                    ]);
                }))
            ),
            $.make('div', { className: 'NB-loading-container' })
        ]));

        this.shown_feed_titles.clear();
        this.trending_feeds_model.each(function (trending_feed) {
            this.shown_feed_titles.add(trending_feed.get("feed").feed_title);
        }, this);

        this.throttled_check_scroll = _.throttle(_.bind(this.check_scroll, this), 100);
        this.$el.on('scroll', this.throttled_check_scroll);

        return this;
    },

    change_time_window: function () {
        var new_days = parseInt(this.$('.NB-trending-time-selector').val(), 10);
        if (new_days !== this.days) {
            this.days = new_days;
            this.page = 1;
            this.has_more_results = true;
            this.trending_feeds_model.reset();
            this.shown_feed_titles.clear();
            this.fetch_data();
        }
    },

    check_scroll: function () {
        if (this.is_loading || !this.has_more_results) return;

        var containerHeight = this.$el.height();
        var scrollTop = this.$el.scrollTop();
        var scrollHeight = this.$el[0].scrollHeight;

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

        this.trending_feeds_model.fetch({
            data: { page: this.page, days: this.days },
            remove: false,
            success: function (model, response) {
                self.render_additional_sites(response.trending_feeds);
                self.has_more_results = response.has_more;
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
        var $feed_badges = this.$('.NB-trending-feed-badges');
        var pane_anchor = NEWSBLUR.assets.preference('story_pane_anchor');

        _.each(new_sites, function (trending_feed_data, feed_id) {
            var feed_title = trending_feed_data.feed.feed_title;

            if (self.shown_feed_titles.has(feed_title)) {
                return;
            }
            self.shown_feed_titles.add(feed_title);

            var $story_titles = $.make('div', { className: 'NB-story-titles' });
            var trending_feed = new NEWSBLUR.Models.TrendingFeed({
                feed: trending_feed_data.feed,
                stories: trending_feed_data.stories,
                trending_score: trending_feed_data.trending_score
            });

            var story_titles_view = new NEWSBLUR.Views.StoryTitlesView({
                el: $story_titles,
                collection: new NEWSBLUR.Collections.Stories(trending_feed_data.stories),
                $story_titles: $story_titles,
                override_layout: 'split',
                pane_anchor: pane_anchor,
                on_trending_feed: trending_feed,
                in_trending_view: self
            });

            var $feed_badge = $.make('div', { className: 'NB-trending-feed-badge' }, [
                new NEWSBLUR.Views.FeedBadge({
                    model: new NEWSBLUR.Models.Feed(trending_feed_data.feed),
                    show_folders: true,
                    in_trending_view: self,
                    load_feed_after_add: false
                }),
                story_titles_view.render().el
            ]);

            $feed_badges.append($feed_badge);
        });
    },

    show_additional_loading: function () {
        this.hide_additional_loading();

        var $endline = $.make('div', { className: "NB-end-line NB-short" });
        $endline.css({ 'background': '#FFF' });
        this.$(".NB-loading-container").append($endline);

        $endline.animate({ 'backgroundColor': '#E1EBFF' }, { 'duration': 550, 'easing': 'easeInQuad' })
            .animate({ 'backgroundColor': '#5C89C9' }, { 'duration': 1550, 'easing': 'easeOutQuad' })
            .animate({ 'backgroundColor': '#E1EBFF' }, 1050);
    },

    hide_additional_loading: function () {
        this.$(".NB-end-line").remove();
    },

    close: function () {
        this.$el.off('scroll');
        this.remove();
    }

});
