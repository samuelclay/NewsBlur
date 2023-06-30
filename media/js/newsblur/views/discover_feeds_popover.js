NEWSBLUR.DiscoverFeedsPopover = NEWSBLUR.ReaderPopover.extend({
    
    className: "NB-filter-popover",
    
    options: {
        'width': 304,
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
    
    initialize: function(options) {
        this.options = _.extend({}, this.options, options);
        this.options.offset.left = -1 * $(this.options.anchor).width() - 31;
        
        // console.log("Opening discover popover", this.options, this.options.feed_id);
        
        NEWSBLUR.ReaderPopover.prototype.initialize.call(this, this.options);
        this.model = NEWSBLUR.assets;
        this.render();
    },

    render: function () {
        var self = this;
        
        NEWSBLUR.ReaderPopover.prototype.render.call(this);
        var feed = this.model.get_feed(this.options.feed_id);
        
        this.$el.html($.make('div', [
            $.make('div', { className: 'NB-popover-section' }, [
                $.make('div', { className: 'NB-popover-section-title' }, 'Discover sites'),
                $.make('div', { className: 'NB-discover-feed-badges' }, _.map(feed.get("discover_feeds"), function(feed) {
                    var model = new NEWSBLUR.Models.Feed(feed);
                    return new NEWSBLUR.Views.FeedBadge({model: model});
                }))
            ])
        ]));
        
        return this;
    }

    
    // ==========
    // = Events =
    // ==========
    

    
});
