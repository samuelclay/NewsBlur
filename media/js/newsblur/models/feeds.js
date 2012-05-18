NEWSBLUR.Models.Feed = Backbone.Model.extend({
    
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
    }
    
    
});