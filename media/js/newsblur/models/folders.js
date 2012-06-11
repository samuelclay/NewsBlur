NEWSBLUR.Models.FeedOrFolder = Backbone.Model.extend({
    
    initialize: function(model) {
        if (_.isNumber(model)) {
            this.feed = NEWSBLUR.assets.feeds.get(model);

            // The feed needs to exists as a model as well. Otherwise, chuck it.
            if (this.feed) {
                this.set('is_feed', true);
            }
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
    
    feed_ids_in_folder: function() {
        if (this.is_feed()) {
            return this.feed.id;
        } else if (this.is_folder()) {
            return this.folders.feed_ids_in_folder();
        }
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
    },
    
    rename: function(new_folder_name) {
        var folder_title = this.get('folder_title');
        var in_folder = this.collection.options.title;
        NEWSBLUR.assets.rename_folder(folder_title, new_folder_name, in_folder);
        this.set('folder_title', new_folder_name);
    },
    
    delete_folder: function() {
        var folder_title = this.get('folder_title');
        var in_folder = this.collection.options.title;
        var feed_ids_in_folder = this.feed_ids_in_folder();
        NEWSBLUR.assets.delete_folder(folder_title, in_folder, feed_ids_in_folder);
        this.trigger('delete');
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
    
    folders: function() {
        return this.select(function(item) {
            return item.is_folder();
        });
    },
    
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
    },
    
    feed_ids_in_folder: function() {
        return _.compact(_.flatten(this.map(function(item) {
            return item.feed_ids_in_folder();
        })));
    },
    
    deselect: function() {
        this.each(function(item) {
            if (item.is_folder()) {
                item.set('selected', false);
                item.folders.deselect();
            }
        });
    },
    
    unread_counts: function() {
        var counts = this.reduce(function(counts, item) {
            if (item.is_feed()) {
                var feed_counts = item.feed.unread_counts();
                counts['ps'] += feed_counts['ps'];
                counts['nt'] += feed_counts['nt'];
                counts['ng'] += feed_counts['ng'];
            } else if (item.is_folder()) {
                var folder_counts = item.folders.unread_counts();
                counts['ps'] += folder_counts['ps'];
                counts['nt'] += folder_counts['nt'];
                counts['ng'] += folder_counts['ng'];
            }
            return counts;
        }, {
            ps: 0,
            nt: 0,
            ng: 0
        });
        
        return counts;
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