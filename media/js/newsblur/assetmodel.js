NEWSBLUR.AssetModel = function() {
    var _Reader = null;
    var _Prefs = null;
    
    return {
        reader: function(){
            if(!_Reader){
                _Reader = new NEWSBLUR.AssetModel.Reader();
                _Reader.init();
            } else {
                _Reader.init();
            }
            return _Reader;
        }
    };
}();

NEWSBLUR.AssetModel.Reader = function() {
    this.feeds = {};
    this.folders = [];
    this.stories = {};
    this.story_keys = [];
    this.read_stories = {};
    this.classifiers = {};
    this.starred_stories = [];
    this.starred_count = 0;
    
    this.DEFAULT_VIEW = NEWSBLUR.Preferences.default_view || 'page';
};

NEWSBLUR.AssetModel.Reader.prototype = {
    
    init: function() {
        this.ajax = {};
        this.ajax['queue'] = $.manageAjax.create('queue', {queue: false}); 
        this.ajax['queue_clear'] = $.manageAjax.create('queue_clear', {queue: 'clear'}); 
        this.ajax['feed'] = $.manageAjax.create('feed', {queue: 'clear', abortOld: true, domCompleteTrigger: true}); 
        this.ajax['feed_page'] = $.manageAjax.create('feed_page', {queue: false, abortOld: true, abortIsNoSuccess: false, domCompleteTrigger: true}); 
        this.ajax['statistics'] = $.manageAjax.create('feed', {queue: 'clear', abortOld: true}); 
        $.ajaxSettings.traditional = true;
        return;
    },
    
    make_request: function(url, data, callback, error_callback, options) {
        var self = this;
        var options = $.extend({
            'ajax_group': 'queue',
            'traditional': true,
            'domSuccessTrigger': true,
            'preventDoubbleRequests': false
        }, options);
        var request_type = 'POST';
        var clear_queue = false;
        
        if (options['ajax_group'] == 'feed') {
            clear_queue = true;
        }
        if (options['ajax_group'] == 'statistics') {
            clear_queue = true;
            request_type = 'GET';
        }
        
        if (clear_queue) {
            this.ajax[options['ajax_group']].clear(true);
        }
        
        this.ajax[options['ajax_group']].add({
            url: url,
            data: data,
            type: request_type,
            dataType: 'json',
            beforeSend: function() {
                // NEWSBLUR.log(['beforeSend', options]);
                $.isFunction(options['beforeSend']) && options['beforeSend']();
                return true;
            },
            success: function(o) {
                // NEWSBLUR.log(['make_request 1', o]);

                if ($.isFunction(callback)) {
                    callback(o);
                }
            },
            error: function(e) {
                // NEWSBLUR.log(['AJAX Error', e]);
                if ($.isFunction(error_callback)) {
                    error_callback();
                } else if ($.isFunction(callback)) {
                    callback({'message': 'Please create an account. Not much to do without an account.'});
                }
            }
        }); 
        
    },
    
    mark_story_as_read: function(story_id, feed_id, callback) {
        var self = this;
        var read = false;
        
        for (s in this.stories) {
            if (this.stories[s].id == story_id) {
                read = this.stories[s].read_status ? true : false;
                this.stories[s].read_status = true;
                break;
            }
        }
        
        if (!read && NEWSBLUR.Globals.is_authenticated) {
            if (!(feed_id in this.read_stories)) { this.read_stories[feed_id] = []; }
            this.read_stories[feed_id].push(story_id);
            NEWSBLUR.log(['Marking Read', this.read_stories, story_id]);
            
            this.make_request('/reader/mark_story_as_read', {
                story_id: this.read_stories[feed_id],
                feed_id: feed_id
            }, function() {}, function() {}, {
                'ajax_group': 'queue_clear',
                'traditional': true,
                'beforeSend': function() {
                    self.read_stories[feed_id] = [];
                }
            });
        }
        
        $.isFunction(callback) && callback(read);
    },
    
    mark_story_as_starred: function(story_id, feed_id, callback) {
        var self = this;
        this.starred_count += 1;
        this.make_request('/reader/mark_story_as_starred', {
            story_id: story_id,
            feed_id:  feed_id
        }, callback);
    },
    
    mark_story_as_unstarred: function(story_id, callback) {
        var self = this;
        this.starred_count -= 1;
        this.make_request('/reader/mark_story_as_unstarred', {
            story_id: story_id
        }, callback);
    },
    
    mark_feed_as_read: function(feed_id, callback) {
        var self = this;
        var feed_ids = _.isArray(feed_id) 
                       ? _.select(feed_id, function(f) { return f; })
                       : [feed_id];
        
        this.make_request('/reader/mark_feed_as_read', {
            feed_id: feed_ids
        }, callback);
    },
    
    load_feeds: function(callback, error_callback) {
        var self = this;
        
        var pre_callback = function(subscriptions) {
            var flat_feeds = function(feeds) {
                var flattened = _.flatten(_.map(feeds, _.values));
                return _.flatten(_.map(flattened, function(feed) {
                    if (!_.isNumber(feed) && feed) return flat_feeds(feed);
                    else return feed;
                }));
            };
            var valid_feeds = flat_feeds({'root': subscriptions.folders});

            _.each(subscriptions.feeds, function(feed, feed_id) {
                if (_.contains(valid_feeds, parseInt(feed_id, 10))) {
                    self.feeds[feed_id] = feed;
                }
            });
            self.folders = subscriptions.folders;
            self.starred_count = subscriptions.starred_count;
            callback();
        };
        
        this.make_request('/reader/load_feeds', {}, pre_callback, error_callback);
    },
    
    load_feed: function(feed_id, page, first_load, callback) {
        var self = this;
        
        var pre_callback = function(data) {
            return self.load_feed_precallback(data, feed_id, callback, first_load);
        };
        
        // NEWSBLUR.log(['load_feed', feed_id, page, first_load, callback, pre_callback, this.feeds[feed_id].feed_address]);
        if (feed_id) {
            this.make_request('/reader/load_single_feed',
                {
                    feed_id: feed_id,
                    page: page,
                    feed_address: this.feeds[feed_id].feed_address
                }, pre_callback,
                null,
                {
                    'ajax_group': (page ? 'feed_page' : 'feed')
                }
            );
        }
    },
    
    load_feed_precallback: function(data, feed_id, callback, first_load) {
        // NEWSBLUR.log(['pre_callback', data]);
        if ((feed_id != this.feed_id && data) || first_load) {
            this.stories = data.stories;
            this.feed_tags = data.feed_tags;
            this.feed_authors = data.feed_authors;
            this.feed_id = feed_id;
            this.classifiers = data.classifiers;
            this.starred_stories = data.starred_stories;
            this.story_keys = [];
            for (var s in data.stories) {
                this.story_keys.push(data.stories[s].id);
            }
        } else if (data) {
            $.merge(this.stories, data.stories);
            
            // Assemble key cache for later, removing dupes
            var data_stories = $.merge([], data.stories);
            for (var s in data_stories) {
                var story_id = data_stories[s].id;
                if (!(story_id in this.story_keys)) {
                    this.story_keys.push(story_id);
                } else {
                    // There's a dupe story. Remove it!
                    for (var s2 in this.stories) {
                        if (story_id == this.stories[s2].id) {
                            delete this.stories[s2];
                            delete data.stories[s];
                            break;
                        }
                    }
                }
            }
        }
        $.isFunction(callback) && callback(data, first_load);
    },
    
    fetch_starred_stories: function(page, callback, first_load) {
        var self = this;
        
        var pre_callback = function(data) {
            return self.load_feed_precallback(data, null, callback, first_load);
        };
        
        this.make_request('/reader/load_starred_stories', {
            page: page
        }, pre_callback, null, {
            'ajax_group': (page ? 'feed_page' : 'feed')
        });
    },
    
    get_feeds_trainer: function(feed_id, callback) {
        var self = this;
        var params = {};
        
        if (feed_id) {
          params['feed_id'] = feed_id;
        }
        
        this.make_request('/reader/get_feeds_trainer', params, callback, null, {'ajax_group': 'feed'});
    },    
    
    
    retrain_all_sites: function(callback) {
        var self = this;
        var params = {};
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/retrain_all_sites', params, callback, null);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },    
    
    refresh_feeds: function(callback, has_unfetched_feeds) {
        var self = this;
        
        var pre_callback = function(data) {
            var updated_feeds = [];

            for (var f in data.feeds) {
                if (!self.feeds[f]) continue;
                var updated = false;
                f = parseInt(f, 10);
                var feed = data.feeds[f];
                for (var k in feed) {
                    if (self.feeds[f][k] != feed[k]) {
                        // NEWSBLUR.log(['New Feed', self.feeds[f][k], feed[k], f, k]);
                        self.feeds[f][k] = feed[k];
                        NEWSBLUR.log(['Different', k, self.feeds[f], feed]);
                        updated = true;
                    }
                }
                if ((feed['has_exception'] && !self.feeds[f]['has_exception']) ||
                    (self.feeds[f]['has_exception'] && !feed['has_exception'])) {
                  updated = true;
                  self.feeds[f]['has_exception'] = !!feed['has_exception'];
                }
                if (updated && !(f in updated_feeds)) {
                    updated_feeds.push(f);
                }
            }
            callback(updated_feeds);
        };
        
        var data = {};
        if (has_unfetched_feeds) {
            data['check_fetch_status'] = has_unfetched_feeds;
        }
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/refresh_feeds', data, pre_callback);
        }
    },
    
    refresh_feed: function(feed_id, callback, limit) {
        var self = this;
        
        var pre_callback = function(data) {
            // NEWSBLUR.log(['refresh_feed pre_callback', data]);
            self.load_feed_precallback(data, feed_id, callback);
        };
        
        // NEWSBLUR.log(['refresh_feed', feed_id, page, first_load, callback, pre_callback]);
        if (feed_id) {
            this.make_request('/reader/load_single_feed',
                {
                    feed_id: feed_id,
                    page: 0,
                    limit: limit,
                    feed_address: this.feeds[feed_id].feed_address
                }, pre_callback,
                null,
                {
                    'ajax_group': 'feed_page'
                }
            );
        }
    },
    
    count_unfetched_feeds: function() {
        var counts = {
            'unfetched_feeds': 0,
            'fetched_feeds': 0
        };
        
        for (var f in this.feeds) {
            var feed = this.feeds[f];
            
            if (feed.active) {
                if (feed['not_yet_fetched']) {
                    counts['unfetched_feeds'] += 1;
                } else {
                    counts['fetched_feeds'] += 1;
                }
            }
        }
        
        return counts;
    },
    
    get_feed: function(feed_id) {
        var self = this;
        
        return this.feeds[feed_id];
    },
    
    get_feeds: function() {
        var self = this;
        
        return this.feeds;
    },
    
    get_folders: function() {
        var self = this;
        
        return this.folders;
    },
    
    get_feed_tags: function() {
        return this.feed_tags;
    },
    
    get_feed_authors: function() {
        return this.feed_authors;
    },
    
    get_story: function(story_id, callback) {
        var self = this;
        for (s in this.stories) {
            if (this.stories[s].id == story_id) {
                return this.stories[s];
            }
        }
        return null;
    },
    
    process_opml_import: function(data, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/import/process', data, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    save_classifier_story: function(story_id, data, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/classifier/save/story/', data, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    save_classifier_publisher: function(data, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/classifier/save/publisher', data, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    get_feed_classifier: function(feed_id, callback) {
        this.make_request('/classifier/get/publisher/', {
            'feed_id': feed_id
        }, callback, null, {
            'ajax_group': 'feed'
        });
    },
    
    delete_feed: function(feed_id, in_folder, callback) {
        delete this.feeds[feed_id];
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/delete_feed', {
                'feed_id': feed_id, 
                'in_folder': in_folder
            }, callback, null);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    delete_folder: function(folder_name, in_folder, feeds, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/delete_folder', {
                'folder_name': folder_name,
                'in_folder': in_folder,
                'feed_id': feeds
            }, callback, null);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    rename_feed: function(feed_id, feed_title, callback) {
        this.feeds[feed_id].feed_title = feed_title;
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/rename_feed', {
                'feed_id'    : feed_id, 
                'feed_title' : feed_title
            }, callback, null);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    rename_folder: function(folder_name, new_folder_name, in_folder, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/rename_folder', {
                'folder_name'     : folder_name,
                'new_folder_name' : new_folder_name,
                'in_folder'       : in_folder
            }, callback, null);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    save_add_url: function(url, folder, callback) {
        this.make_request('/reader/add_url/', {
            'url': url,
            'folder': folder
        }, callback, null);
    },
    
    save_add_folder: function(folder, parent_folder, callback) {
        this.make_request('/reader/add_folder/', {
            'folder': folder,
            'parent_folder': parent_folder
        }, callback, null);
    },
    
    preference: function(preference, value, callback) {
        if (typeof value == 'undefined') {
            var pref = NEWSBLUR.Preferences[preference];
            if ((/\d+/).test(pref)) return parseInt(pref, 10);
            return pref;
        }
        
        if (NEWSBLUR.Preferences[preference] == value) {
          return $.isFunction(callback) && callback();
        }
        
        NEWSBLUR.Preferences[preference] = value;
        var preferences = {};
        preferences[preference] = value;
        this.make_request('/profile/set_preference', preferences, callback, null);
    },
    
    save_preferences: function(preferences, callback) {
        _.each(preferences, function(value, preference) {
            NEWSBLUR.Preferences[preference] = value;
        });
        
        this.make_request('/profile/set_preference', preferences, callback, null);
    },
    
    view_setting: function(feed_id, feed_view_setting, callback) {
        if (typeof feed_view_setting == 'undefined') {
            return NEWSBLUR.Preferences.view_settings[feed_id+''] || this.DEFAULT_VIEW;
        }
        
        NEWSBLUR.Preferences.view_settings[feed_id+''] = feed_view_setting;
        this.make_request('/profile/set_view_setting', {
            'feed_id': feed_id+'',
            'feed_view_setting': feed_view_setting
        }, callback, null);
    },
    
    collapsed_folders: function(folder_title, is_collapsed, callback) {
        var folders = NEWSBLUR.Preferences.collapsed_folders;
        var changed = false;
        
        if (is_collapsed && !_.contains(NEWSBLUR.Preferences.collapsed_folders, folder_title)) {
            NEWSBLUR.Preferences.collapsed_folders.push(folder_title);
            changed = true;
        } else if (!is_collapsed && _.contains(NEWSBLUR.Preferences.collapsed_folders, folder_title)) {
            NEWSBLUR.Preferences.collapsed_folders = _.without(folders, folder_title);
            changed = true;
        }
        this.make_request('/profile/set_collapsed_folders', {
            'collapsed_folders': $.toJSON(NEWSBLUR.Preferences.collapsed_folders)
        }, callback, null);
    },
    
    save_mark_read: function(days, callback) {
        this.make_request('/reader/mark_all_as_read', {'days': days}, callback);
    },
    
    get_features_page: function(page, callback) {
        this.make_request('/reader/load_features', {'page': page}, callback);
    },
    
    save_feed_order: function(folders, callback) {
        this.make_request('/reader/save_feed_order', {'folders': $.toJSON(folders)}, callback);
    },
    
    get_feed_statistics: function(feed_id, callback) {
        this.make_request('/rss_feeds/statistics', {
            'feed_id': feed_id
        }, callback, callback, {
            'ajax_group': 'statistics'
        });
    },
    
    start_import_from_google_reader: function(callback) {
        this.make_request('/import/import_from_google_reader/', {}, callback);
    },
        
    save_exception_retry: function(feed_id, callback) {
        var self = this;
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/rss_feeds/exception_retry', {
              'feed_id': feed_id, 
              'reset_fetch': !!(this.feeds[feed_id].has_feed_exception || this.feeds[feed_id].has_page_exception)
            }, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
        
    save_exception_change_feed_link: function(feed_id, feed_link, callback) {
        var self = this;
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/rss_feeds/exception_change_feed_link', {
                'feed_id': feed_id,
                'feed_link': feed_link
            }, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
        
    save_exception_change_feed_address: function(feed_id, feed_address, callback) {
        var self = this;
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/rss_feeds/exception_change_feed_address', {
                'feed_id': feed_id,
                'feed_address': feed_address
            }, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    save_feed_chooser: function(approved_feeds, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/save_feed_chooser', {
                'approved_feeds': _.select(approved_feeds, function(f) { return f; })
            }, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    }

};


