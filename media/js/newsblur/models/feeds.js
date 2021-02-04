NEWSBLUR.Models.Feed = Backbone.Model.extend({
    
    initialize: function() {
        _.bindAll(this, 'on_change', 'delete_feed', 'update_folder_counts');
        // this.bind('change', this.on_change);
        this.bind('change:ps', this.change_counts);
        this.bind('change:nt', this.change_counts);
        this.bind('change:ng', this.change_counts);
        this.bind('change:selected', this.update_folder_visibility);
        this.views = [];
        this.folders = [];
    },
    
    on_change: function() {
        if (!('selected' in this.changedAttributes())) {
            NEWSBLUR.log(['Feed Change', this.changedAttributes(), this.previousAttributes()]);
        }
    },
    
    change_counts: function(data, count, options) {
        options = options || {};
        // console.log(["change_counts", data, count, options]);
        this.update_folder_counts();
        
        if (this.get('selected') && options.refresh_feeds) {
            console.log(["Selected feed count change", this]);
            NEWSBLUR.reader.feed_unread_count(this.id);
        }
    },
    
    force_update_counts: function() {
        NEWSBLUR.reader.feed_unread_count(this.id);
    },
    
    update_folder_counts: function() {
        _.each(this.folders, function(folder) {
            folder.trigger('change:counts');
        });
    },
    
    update_folder_visibility: function() {
        _.each(this.folders, function(folder) {
            folder.trigger('change:feed_selected');
        });
    },
    
    delete_feed: function(options) {
        options = options || {};
        var view = options.view || this.get_view();

        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        NEWSBLUR.assets.delete_feed(this.id, view.options.folder_title, function() {
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
        });
        view.delete_feed();
    },
    
    move_to_folder: function(to_folder, options) {
        options = options || {};
        var view = options.view || this.get_view();
        var in_folder = view.options.folder_title;
        
        if (in_folder == to_folder) return false;

        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        NEWSBLUR.assets.move_feed_to_folder(this.id, in_folder, to_folder, function() {
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
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
    
    move_to_folders: function(to_folders, options) {
        options = options || {};
        var view = options.view || this.get_view();
        var in_folders = this.in_folders();
        
        if (_.isEqual(in_folders, to_folders)) return false;

        NEWSBLUR.reader.flags['reloading_feeds'] = true;
        NEWSBLUR.assets.move_feed_to_folders(this.id, in_folders, to_folders, function() {
            NEWSBLUR.reader.flags['reloading_feeds'] = false;
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
    
    parent_folder_names: function() {
        var names = _.compact(_.flatten(_.map(this.folders, function(folder) {
            return folder.parent_folder_names();
        })));
        
        return names;
    },
    
    in_folders: function() {
        var in_folders = _.pluck(_.pluck(this.folders, 'options'), 'title');

        return in_folders;
    },
    
    rename: function(new_title) {
        this.set('feed_title', new_title);
        NEWSBLUR.assets.rename_feed(this.id, new_title);
    },
    
    get_view: function($feed, fallback) {
        var found_view = _.detect(this.views, function(view) {
            if ($feed) {
                return view.el == $feed.get(0);
            } else {
                return true;
            }
        });
        
        if (!found_view && fallback && this.views.length) {
            found_view = this.views[0];
        }
        
        return found_view;
    },
    
    is_social: function() {
        return false;
    },
    
    is_feed: function() {
        return true;
    },
    
    is_starred: function() {
        return false;
    },
    
    is_search: function() {
        return false;
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
    },
    
    unread_counts: function() {
        var starred_feed = NEWSBLUR.assets.starred_feeds.get_feed(this.id);
        return {
            ps: this.get('ps') || 0,
            nt: this.get('nt') || 0,
            ng: this.get('ng') || 0,
            st: starred_feed && starred_feed.get('count') || 0
        };
    },
    
    has_unreads: function(options) {
        options = options || {};
        var unread_view = NEWSBLUR.assets.preference('unread_view');
        
        if (options.include_selected && this.get('selected')) {
            return true;
        }
        
        if (!this.get('active')) return false;
        
        if (unread_view <= -1) {
            return !!(this.get('ng') || this.get('nt') || this.get('ps'));
        } else if (unread_view == 0) {
            return !!(this.get('nt') || this.get('ps'));
        } else if (unread_view >= 2) {
            var starred_feed = NEWSBLUR.assets.starred_feeds.get_feed(this.id);
            return starred_feed && starred_feed.get('count');
        } else if (unread_view > 0) {
            return !!(this.get('ps'));
        }
    },
    
    relative_last_story_date: function() {
        var diff = this.get('last_story_seconds_ago');
        var lasthour = 60*60;
        var lastday = 24*60*60;

        if (diff > 1000*60*60*24*365*20 || diff <= 0) {
            return "Never";
        } else if (diff < lasthour) {
            return Inflector.pluralize("minute", Math.floor(diff/60), true) + " ago";
        } else if (diff < lastday) {
            return Inflector.pluralize("hour", Math.floor(diff/60/60), true) + " ago";
        } else {
            return Inflector.pluralize("day", Math.floor(diff/60/60/24), true) + " ago";
        }
    },
    
    highlighted_in_folder: function(folder_title) {
        return !!(this.get('highlighted') && 
                  this.get('highlighted_in_folders') &&
                  _.contains(this.get('highlighted_in_folders'), folder_title));
    },
    
    highlight_in_folder: function(folder_title, on, off, options) {
        options = options || {};
        
        if (!this.get('highlighted_in_folders')) {
            this.set('highlighted_in_folders', [], {silent: true});
        }
        
        if (!off && (on || !_.contains(this.get('highlighted_in_folders'), folder_title))) {
            this.set('highlighted_in_folders', 
                      this.get('highlighted_in_folders').concat(folder_title), {silent: true});
        } else {
            this.set('highlighted_in_folders', 
                     _.without(this.get('highlighted_in_folders'), folder_title), {silent: true});
        }
        this.set('highlighted', !!this.get('highlighted_in_folders').length, {silent: true});

        if (!options.silent) this.trigger('change:highlighted');
    },
    
    highlight_in_all_folders: function(on, off, options) {
        options = options || {};
        
        if (!this.get('highlighted_in_folders')) {
            this.set('highlighted_in_folders', [], {silent: true});
        }
        var folders = _.unique(this.in_folders()) || [];
        
        if (!off && (on || !this.get('highlighted_in_folders').length)) {
            this.set('highlighted_in_folders', folders, {silent: true});
        } else {
            this.set('highlighted_in_folders', [], {silent: true});
        }
        this.set('highlighted', !!this.get('highlighted_in_folders').length, {silent: true});

        if (!options.silent) this.trigger('change:highlighted');
    }
    
});

NEWSBLUR.Collections.Feeds = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.Feed,
    
    url: '/reader/feeds',
    
    active_feed: null,
    
    initialize: function() {
        this.bind('change', this.detect_active_feed);
    },
    
    comparator: 'feed_title',
    
    // ===========
    // = Actions =
    // ===========
    
    fetch: function(options) {
        var data = {
            'v': 2,
            'update_counts': false
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

        this.ensure_authenticated(data);
        
        return data.feeds;
    },
    
    deselect: function() {
        this.each(function(feed){ 
            feed.set('selected', false); 
        });
    },
    
    ensure_authenticated: function(data) {
        if (!NEWSBLUR.Globals.is_authenticated) return;
        if (_.isUndefined(data.authenticated)) return;
        if (NEWSBLUR.Globals.is_authenticated != data.authenticated) {
            console.log(['Woah! Lost auth cookie, letting user know...']);
            // NEWSBLUR.reader.show_authentication_lost();
        }
    },
    
    // ==================
    // = Model Managers =
    // ==================
    
    selected: function() {
        return this.detect(function(feed) { return feed.get('selected'); });
    },
    
    active: function() {
        return this.select(function(feed) { return feed.get('active'); });
    },
    
    has_chosen_feeds: function() {
        return this.any(function(feed) {
            return feed.get('active');
        });
    },
    
    has_unfetched_feeds: function() {
        return this.any(function(feed) {
            return feed.get('not_yet_fetched');
        });
    },
    
    // ============
    // = Counters =
    // ============
    
    search_indexed: function() {
        var indexed = this.select(function(feed) {
            return feed.get('search_indexed');
        }).length;

        return indexed;
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
