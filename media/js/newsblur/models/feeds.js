NEWSBLUR.Models.Feed = Backbone.Model.extend({
    
    initialize: function() {
        _.bindAll(this, 'on_change');
        this.bind('change', this.on_change);
    },
    
    on_change: function() {
        NEWSBLUR.log(['Feed Change', this.changedAttributes(), this.previousAttributes()]);
    },
    
    is_social: function() {
        return false;
    },
    
    is_feed: function() {
        return true;
    }
    
});

NEWSBLUR.Collections.Feeds = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.Feed,
    
    url: '/reader/feeds',
    
    fetch: function(options) {
        options = _.extend({
            data: {
                v: 2
            },
            silent: true
        }, options);
        return Backbone.Collection.prototype.fetch.call(this, options);
    },
    
    parse: function(data) {
        return data.feeds;
    },
    
    has_chosen_feeds: function() {
        return this.any(function(feed) {
            return feed.get('active');
        });
    },
    
    deselect: function() {
        this.chain().select(function(feed) { 
            return feed.get('selected'); 
        }).each(function(feed){ 
            feed.set('selected', false); 
        });
    }
    
});