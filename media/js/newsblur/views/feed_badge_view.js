NEWSBLUR.Views.FeedBadge = Backbone.View.extend({
    
    className: "NB-feed-badge",
    
    events: {
        "click .NB-badge-action-try"    : "try_feed",
        "click .NB-badge-action-add"    : "add_feed",
        "click .NB-icon-stats"          : "open_stats"
    },
    
    constructor : function(options) {
        Backbone.View.call(this, options);
        this.render();

        return this.el;
    },
    
    initialize: function() {
        _.bindAll(this, 'render');
        this.model.bind('change', this.render);
    },
    
    render: function() {
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
            (!subscribed && $.make('div', [
                $.make('div', { 
                    className: 'NB-badge-action-try NB-modal-submit-button NB-modal-submit-green' 
                }, [
                    $.make('span', 'Try')
                ]),
                $.make('div', { 
                    className: 'NB-badge-action-add NB-modal-submit-button NB-modal-submit-grey '
                }, 'Add')
            ]))
        ]));

        return this;
    },
    
    try_feed: function() {
        NEWSBLUR.reader.load_feed_in_tryfeed_view(this.model.id);
    },
    
    add_feed: function() {
        NEWSBLUR.reader.open_add_feed_modal({url: this.model.get('feed_address')});
    },
    
    open_stats: function() {
        NEWSBLUR.assets.load_canonical_feed(this.model.id, _.bind(function() {
            NEWSBLUR.reader.open_feed_statistics_modal(this.model.id);
        }, this));

    }
    
});