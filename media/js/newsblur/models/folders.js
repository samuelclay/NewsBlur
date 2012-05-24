NEWSBLUR.Models.FeedOrFolder = Backbone.Model.extend({
    
    initialize: function(model) {
        if (_.isNumber(model)) {
            this.feed = NEWSBLUR.assets.feeds.get(model);
            this.set('is_feed', true);
        } else if (model) {
            var title = _.keys(model)[0];
            var children = model[title];
            this.set('is_folder', true);
            this.set('folder_title', title);
            this.folder_views = [];
            this.folders = new NEWSBLUR.Collections.Folders([], {title: title});
            this.folders.reset(_.compact(children));
        }
    },
    
    is_feed: function() {
        return this.get('is_feed', false);
    },
    
    is_folder: function() {
        return this.get('is_folder', false);
    },
    
    get_view: function($folder) {
        var view = _.detect(this.folder_views, function(view) {
            if ($folder) {
                return view.el == $folder.get(0);
            }
        });
        if (!view && this.folders.length) {
            view = this.folders.get_view($folder);
        }
        return view;
    },
    
    move_to_folder: function(to_folder, options) {
        options = options || {};
        var view = options.view || this.get_view();
        var in_folder = this.collection.options.title;
        var folder_title = this.get('folder_title');
        if (in_folder == to_folder) return false;
        
        NEWSBLUR.assets.move_folder_to_folder(folder_title, in_folder, to_folder, function() {
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
    }
    
});

NEWSBLUR.Collections.Folders = Backbone.Collection.extend({
    
    options: {
        title: ''
    },
    
    initialize: function(models, options) {
        this.options = options || {};
        this.comparator = NEWSBLUR.Collections.Folders.comparator;
    },
    
    model: NEWSBLUR.Models.FeedOrFolder,
    
    get_view: function($folder) {
        var view;
        this.any(function(item) {
            if (item.is_folder()) {
                view = item.get_view($folder);
                return view;
            }
        });
        if (view) {
            return view;
        }
    },
    
    child_folder_names: function() {
        var names = [];
        this.each(function(item) {
            if (item.is_folder()) {
                names.push(item.get('folder_title'));
                _.each(item.folders.child_folder_names(), function(name) {
                    names.push(name);
                });
            }
        });
        return names;
    }
    
}, {
    
    comparator: function(modelA, modelB) {
        var sort_order = NEWSBLUR.assets.preference('feed_order');
        
        
        if (modelA.is_feed() != modelB.is_feed()) {
            // Feeds above folders
            return modelA.is_feed() ? -1 : 1;
        }
        if (modelA.is_folder()) {
            // Folders are alphabetical
            return modelA.get('folder_title').toLowerCase() > modelB.get('folder_title').toLowerCase() ? 1 : -1;
        }
        
        var feedA = modelA.feed;
        var feedB = modelB.feed;
        if (sort_order == 'ALPHABETICAL' || !sort_order) {
            return feedA.get('feed_title').toLowerCase() > feedB.get('feed_title').toLowerCase() ? 1 : -1;
        } else if (sort_order == 'MOSTUSED') {
            return feedA.get('feed_opens') < feedB.get('feed_opens') ? 1 : 
                (feedA.get('feed_opens') > feedB.get('feed_opens') ? -1 : 
                (feedA.get('feed_title').toLowerCase() > feedB.get('feed_title').toLowerCase() ? 1 : -1));
        }
    }

});