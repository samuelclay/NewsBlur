NEWSBLUR.Models.Feed = Backbone.Model.extend({
    
    initialize: function() {
        _.bindAll(this, 'on_change', 'delete_feed');
        this.bind('change', this.on_change);
        this.views = [];
    },
    
    on_change: function() {
        // NEWSBLUR.log(['Feed Change', this.changedAttributes(), this.previousAttributes()]);
    },
    
    delete_feed: function(options) {
        options = options || {};
        var view = options.view || this.get_view();
        console.log(["Delete Feed", this, view, view.options.folder_title]);
        
        NEWSBLUR.assets.delete_feed(this.id, view.options.folder_title);
        view.delete_feed();
    },
    
    get_view: function($feed) {
        return _.detect(this.views, function(view) {
            if ($feed) {
                return view.el == $feed.get(0);
            } else {
                return true;
            }
        });
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
        _.each(data.feeds, function(feed) {
            feed.selected = false;
        });
        return data.feeds;
    },
    
    selected: function() {
        return this.detect(function(feed) { return feed.get('selected'); });
    },
    
    has_chosen_feeds: function() {
        return this.any(function(feed) {
            return feed.get('active');
        });
    },
    
    deselect: function() {
        this.each(function(feed){ 
            feed.set('selected', false); 
        });
    }
    
});