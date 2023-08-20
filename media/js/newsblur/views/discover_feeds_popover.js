NEWSBLUR.DiscoverFeedsPopover = NEWSBLUR.ReaderPopover.extend({

    className: "NB-filter-popover",

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

        // console.log("Opening discover popover", this.options, this.options.feed_id);

        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.model = NEWSBLUR.assets;

        this.discover_feeds_model = new NEWSBLUR.Collections.DiscoverFeeds();

        this.fetchData();
    },

    fetchData: function () {
        var self = this;

        var feed = this.model.get_feed(this.options.feed_id);
        this.discover_feeds_model.feed_ids = feed.get("discover_feeds");;

        NEWSBLUR.ReaderPopover.prototype.render.call(this);

        this.showLoading();
        this.discover_feeds_model.fetch({
            success: function () {
                self.hideLoading();
                self.render();
            },
            error: function () {
                self.hideLoading();
            }
        });
    },

    showLoading: function () {

        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, 'Discover sites'),
                $.make('div', { className: 'NB-discover-loading' }, "Loading...")
            ])
        ]));
    },

    hideLoading: function () {
        this.$el.html('');
    },

    onDataLoaded: function () {
        this.hideLoading();
        this.render();
    },

    onDataLoadError: function () {
        // Handle the error, for example:
        this.$el.html('<div class="error-message">Failed to load data</div>');
    },

    render: function () {
        var self = this;

        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, 'Discover sites'),
                $.make('div', { className: 'NB-discover-feed-badges' }, _.flatten(this.discover_feeds_model.map(function (discover_feed) {
                    return [
                        new NEWSBLUR.Views.FeedBadge({ model: discover_feed.get("feed") }),
                        new NEWSBLUR.Views.StoryTitlesView({ collection: discover_feed.get("stories"), on_dashboard: true }).render().el
                    ];
                })))
            ])
        ]));

        this.check_height();

        return this;
    }


    // ==========
    // = Events =
    // ==========



});
