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
    this.read_stories = {};
    this.classifiers = {};
    
    this.DEFAULT_VIEW = 'page';
};

NEWSBLUR.AssetModel.Reader.prototype = {
    
    init: function() {
        this.ajax = {};
        this.ajax['queue'] = $.manageAjax.create('queue', {queue: false, domSuccessTrigger: true, traditional: true}); 
        this.ajax['queue_clear'] = $.manageAjax.create('queue_clear', {queue: 'clear', domSuccessTrigger: true, traditional: true}); 
        this.ajax['feed'] = $.manageAjax.create('feed', {queue: 'clear', abortOld: true, domSuccessTrigger: true, traditional: true}); 
        this.ajax['feed_page'] = $.manageAjax.create('feed_page', {queue: false, abortOld: true, abortIsNoSuccess: false, domSuccessTrigger: true, domCompleteTrigger: true, traditional: true}); 
        return;
    },
    
    make_request: function(url, data, callback, error_callback, options) {
        var self = this;
        var options = $.extend({
            'ajax_group': 'queue',
            'traditional': true,
            'preventDoubbleRequests': false
        }, options);
        
        if (options['ajax_group'] == 'feed') {
            this.ajax[options['ajax_group']].clear(true);
        }
        
        this.ajax[options['ajax_group']].add({
            url: url,
            data: data,
            type: 'POST',
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
            
            var story_ids = new Array(this.read_stories[feed_id]);
            this.make_request('/reader/mark_story_as_read', {
                story_id: story_ids,
                feed_id: feed_id
            }, function() {}, function() {}, {
                'ajax_group': 'queue_clear',
                'traditional': true,
                'beforeSend': function() {
                    self.read_stories[feed_id] = [];
                }
            });
        }
        
        callback(read);
    },
    
    mark_story_as_like: function(story_id, callback) {
        var self = this;
        var opinion;
        
        for (s in this.stories) {
            if (this.stories[s].id == story_id) {
                opinion = this.stories[s].opinion;
                this.stories[s].opinion = 1;
                break;
            }
        }
        
        NEWSBLUR.log(['Like', opinion, this.stories[s].opinion]);
        if (opinion != 1) {
            this.make_request('/reader/mark_story_as_like',
                {
                    story_id: story_id
                }, callback
            );
        }
    },
    
    mark_story_as_dislike: function(story_id, callback) {
        var self = this;
        var opinion;
        
        for (s in this.stories) {
            if (this.stories[s].id == story_id) {
                opinion = this.stories[s].opinion;
                this.stories[s].opinion = -1;
                break;
            }
        }
        NEWSBLUR.log(['Dislike', opinion, this.stories[s].opinion]);
        if (opinion != -1) {
            this.make_request('/reader/mark_story_as_dislike',
                {
                    story_id: story_id
                }, callback
            );
        }
    },
    
    mark_feed_as_read: function(feed_id, callback) {
        var self = this;
        
        this.make_request('/reader/mark_feed_as_read',
            {
                feed_id: feed_id
            }, callback
        );
    },
    
    load_feeds: function(callback) {
        var self = this;
        
        var pre_callback = function(subscriptions) {
            self.feeds = subscriptions.feeds;
            self.folders = subscriptions.folders;
            callback();
        };
        
        this.make_request('/reader/load_feeds', {}, pre_callback);
    },
    
    load_feed: function(feed_id, page, first_load, callback) {
        var self = this;
        
        var pre_callback = function(data) {
            return self.load_feed_precallback(data, feed_id, callback, first_load);
        };
        
        // NEWSBLUR.log(['load_feed', feed_id, page, first_load, callback, pre_callback]);
        if (feed_id) {
            this.make_request('/reader/load_single_feed',
                {
                    feed_id: feed_id,
                    page: page
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
        if (feed_id != this.feed_id) {
            this.stories = data.stories;
            this.feed_tags = data.feed_tags;
            this.feed_authors = data.feed_authors;
            this.feed_id = feed_id;
            this.classifiers = data.classifiers;
            this.story_keys = [];
            for (var s in data.stories) {
                this.story_keys.push(data.stories[s].id);
            }
        } else {
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
    
    refresh_feeds: function(callback) {
        var self = this;
        
        var pre_callback = function(feeds) {
            var updated_feeds = [];
            
            for (var f in feeds) {
                f = parseInt(f, 10);
                var feed = feeds[f];
                for (var k in feed) {
                    if (self.feeds[f][k] != feed[k]) {
                        // NEWSBLUR.log(['New Feed', self.feeds[f][k], feed[k], f, k]);
                        self.feeds[f][k] = feed[k];
                        if (!(f in updated_feeds)) {
                            updated_feeds.push(f);
                            break;
                        }
                    }
                }
            }
            callback(updated_feeds);
        };
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/refresh_feeds', {}, pre_callback);
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
                    limit: limit
                }, pre_callback,
                null,
                {
                    'ajax_group': 'feed_page'
                }
            );
        }
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
        var self = this;
        
        this.make_request('/import/process', data, callback);
    },
    
    save_classifier_story: function(story_id, data, callback) {
        this.make_request('/classifier/save/story/', data, callback);
    },
    
    save_classifier_publisher: function(data, callback) {
        this.make_request('/classifier/save/publisher', data, callback);
    },
    
    get_feed_classifier: function(feed_id, callback) {
        this.make_request('/classifier/get/publisher/', {
            'feed_id': feed_id
        }, callback, null, {
            'ajax_group': 'feed'
        });
    },
    
    delete_publisher: function(feed_id, callback) {
        delete this.feeds[feed_id];
        this.make_request('/reader/delete_feed', {'feed_id': feed_id}, callback, null);
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
            return NEWSBLUR.Preferences[preference];
        }
        
        NEWSBLUR.Preferences[preference] = value;
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/profile/set_preference', {
                'preference': preference,
                'value': value
            }, callback, null);
        }
    },
    
    view_setting: function(feed_id, feed_view_setting, callback) {
        if (typeof feed_view_setting == 'undefined') {
            return NEWSBLUR.Preferences.view_settings[feed_id+''] || this.DEFAULT_VIEW;
        }
        
        NEWSBLUR.Preferences.view_settings[feed_id+''] = feed_view_setting;
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/profile/set_view_setting', {
                'feed_id': feed_id+'',
                'feed_view_setting': feed_view_setting
            }, callback, null);
        }
    },
    
    save_mark_read: function(days, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/mark_all_as_read', {'days': days}, callback);
        } else {
            if ($.isFunction(callback)) {
                callback(o);
            }
        }
    },
    
    get_features_page: function(page, callback) {
        this.make_request('/reader/load_features', {'page': page}, callback);
    }
    
};


