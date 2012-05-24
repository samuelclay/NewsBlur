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
        console.log(["Delete Feed", this, view, view.collection.options.title]);
        
        NEWSBLUR.assets.delete_feed(this.id, view.collection.options.title);
        view.delete_feed();
    },
    
    move_to_folder: function(to_folder, options) {
        options = options || {};
        var view = options.view || this.get_view();
        var in_folder = view.options.folder_title;
        
        if (in_folder == to_folder) return false;
        
        NEWSBLUR.assets.move_feed_to_folder(this.id, in_folder, to_folder, function() {
            _.delay(function() {
                NEWSBLUR.reader.$s.$feed_list.css('opacity', 1).animate({'opacity': 0}, {
                    'duration': 100, 
                    'complete': function() {
                        NEWSBLUR.app.feed_list.make_feeds();
                    }
                });
            }, 250);
        });
        
        return true;
    },
    
    rename: function(new_title) {
        this.set('feed_title', new_title);
        NEWSBLUR.assets.rename_feed(this.id, new_title);
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