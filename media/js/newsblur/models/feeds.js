NEWSBLUR.Models.Feed = Backbone.Model.extend({
    
    initialize: function() {
        _.bindAll(this, 'on_change', 'delete_feed');
        this.bind('change', this.on_change);
        this.views = [];
    },
    
    on_change: function() {
        if (!('selected' in this.changedAttributes())) {
            NEWSBLUR.log(['Feed Change', this.changedAttributes(), this.previousAttributes()]);
        }
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
    },
    
    is_light: function() {
        var is_light = this._is_light;
        if (!_.isUndefined(is_light)) {
            return is_light;
        }
        var color = this.get('favicon_color');
        if (!color) return false;
    
        var r = parseInt(color.substr(0, 2), 16) / 255.0;
        var g = parseInt(color.substr(2, 2), 16) / 255.0;
        var b = parseInt(color.substr(4, 2), 16) / 255.0;

        is_light = $.textColor({r: r, g: g, b: b}) != 'white';
        this._is_light = is_light;
        return is_light;
    }
    
});

NEWSBLUR.Collections.Feeds = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.Feed,
    
    url: '/reader/feeds',
    
    active_feed: null,
    
    initialize: function() {
        this.bind('change', this.detect_active_feed);
    },
    
    // ===========
    // = Actions =
    // ===========
    
    fetch: function(options) {
        var data = {
            'v': 2
        };

        options = _.extend({
            data: data,
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
    
    deselect: function() {
        this.each(function(feed){ 
            feed.set('selected', false); 
        });
    },
    
    // ==================
    // = Model Managers =
    // ==================
    
    selected: function() {
        return this.detect(function(feed) { return feed.get('selected'); });
    },
    
    has_chosen_feeds: function() {
        return this.any(function(feed) {
            return feed.get('active');
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    detect_active_feed: function() {
        this.active_feed = this.detect(function(feed) {
            return feed.get('selected');
        });
    }
    
});