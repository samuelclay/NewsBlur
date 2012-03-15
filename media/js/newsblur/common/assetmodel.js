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
    this.defaults = {
        classifiers: {
            titles: {},
            tags: {},
            authors: {},
            feeds: {}
        }
    };
    this.feeds = {};
    this.social_feeds = new NEWSBLUR.Collections.SocialSubscriptions();
    this.favicons = {};
    this.folders = [];
    this.stories = {};
    this.story_keys = {};
    this.queued_read_stories = {};
    this.classifiers = {};
    this.friends = {};
    this.profile = {};
    this.user_profile = new NEWSBLUR.Models.User();
    this.user_profiles = new NEWSBLUR.Collections.Users();
    this.follower_profiles = new NEWSBLUR.Collections.Users();
    this.following_profiles = new NEWSBLUR.Collections.Users();
    this.starred_stories = [];
    this.starred_count = 0;
    this.read_stories_river_count = 0;
    this.flags = {
        'favicons_fetching': false,
        'has_chosen_feeds': false
    };
};

NEWSBLUR.AssetModel.Reader.prototype = {
    
    init: function() {
        this.ajax = {};
        this.ajax['rapid']       = $.manageAjax.create('rapid', {queue: false});
        this.ajax['queue']       = $.manageAjax.create('queue', {queue: true}); 
        this.ajax['queue_clear'] = $.manageAjax.create('queue_clear', {queue: 'clear'}); 
        this.ajax['feed']        = $.manageAjax.create('feed', {queue: 'clear', abortOld: true, 
                                                                domCompleteTrigger: true}); 
        this.ajax['feed_page']   = $.manageAjax.create('feed_page', {queue: 'clear', abortOld: true, 
                                                                     abortIsNoSuccess: false, 
                                                                     domCompleteTrigger: true}); 
        this.ajax['statistics']  = $.manageAjax.create('statistics', {queue: 'clear', abortOld: true}); 
        $.ajaxSettings.traditional = true;
        return;
    },
    
    make_request: function(url, data, callback, error_callback, options) {
        var self = this;
        var options = $.extend({
            'ajax_group': 'queue',
            'traditional': true,
            'domSuccessTrigger': true,
            'preventDoubleRequests': false
        }, options);
        var request_type = options.request_type || 'POST';
        var clear_queue = false;
        
        if (options['ajax_group'] == 'feed') {
            clear_queue = true;
        }
        if (options['ajax_group'] == 'statistics') {
            clear_queue = true;
        }
        
        if (clear_queue) {
            this.ajax[options['ajax_group']].clear(true);
        }

        this.ajax[options['ajax_group']].add(_.extend({
            url: url,
            data: data,
            type: request_type,
            cache: false,
            cacheResponse: false,
            beforeSend: function() {
                // NEWSBLUR.log(['beforeSend', options]);
                $.isFunction(options['beforeSend']) && options['beforeSend']();
                return true;
            },
            success: function(o) {
                // NEWSBLUR.log(['make_request 1', o]);
                
                if (o && o.code < 0 && error_callback) {
                    error_callback(o);
                } else if ($.isFunction(callback)) {
                    callback(o);
                }
            },
            error: function(e, textStatus, errorThrown) {
                NEWSBLUR.log(['AJAX Error', e, textStatus, errorThrown, !!error_callback, error_callback]);
                if (errorThrown == 'abort') {
                    return;
                }
                
                if (error_callback) {
                    error_callback();
                } else if ($.isFunction(callback)) {
                    var message = "Please create an account. Not much to do without an account.";
                    if (NEWSBLUR.Globals.is_authenticated) {
                      message = "Sorry, there was an unhandled error.";
                    }
                    callback({'message': message});
                }
            }
        }, options)); 
        
    },
    
    mark_story_as_read: function(story_id, feed_id, callback) {
        var self = this;
        var story = this.get_story(story_id);
        var read = story.read_status;
        
        if (!story.read_status) {
            story.read_status = 1;
            
            if (NEWSBLUR.Globals.is_authenticated) {
                if (!(feed_id in this.queued_read_stories)) { this.queued_read_stories[feed_id] = []; }
                this.queued_read_stories[feed_id].push(story_id);
                // NEWSBLUR.log(['Marking Read', this.queued_read_stories, story_id]);
            
                this.make_request('/reader/mark_story_as_read', {
                    story_id: this.queued_read_stories[feed_id],
                    feed_id: feed_id
                }, null, null, {
                    'ajax_group': $.browser.msie ? 'rapid' : 'queue_clear',
                    'beforeSend': function() {
                        self.queued_read_stories = {};
                    }
                });
            }
        }
        
        this.read_stories_river_count += 1;
        $.isFunction(callback) && callback(read);
    },
    
    mark_social_story_as_read: function(story_id, social_feed_id, callback) {
        var self = this;
        var story = this.get_story(story_id);
        var feed_id = story.story_feed_id;
        var social_user_id = this.social_feeds.get(social_feed_id).get('user_id');
        var read = story.read_status;

        if (!story.read_status) {
            story.read_status = 1;
            
            if (NEWSBLUR.Globals.is_authenticated) {
                if (!(social_user_id in this.queued_read_stories)) { 
                    this.queued_read_stories[social_user_id] = {};
                }
                if (!(feed_id in this.queued_read_stories[social_user_id])) {
                    this.queued_read_stories[social_user_id][feed_id] = [];
                }
                this.queued_read_stories[social_user_id][feed_id].push(story_id);
                // NEWSBLUR.log(['Marking Read', this.queued_read_stories, story_id]);
            
                this.make_request('/reader/mark_social_stories_as_read', {
                    users_feeds_stories: $.toJSON(this.queued_read_stories)
                }, null, null, {
                    'ajax_group': 'queue_clear',
                    'beforeSend': function() {
                        self.queued_read_stories = {};
                    }
                });
            }
        }
        
        this.read_stories_river_count += 1;
        $.isFunction(callback) && callback(read);
    },
    
    mark_story_as_unread: function(story_id, feed_id, callback) {
        var self = this;
        var read = true;
        
        for (s in this.stories) {
            if (this.stories[s].id == story_id) {
                this.stories[s].read_status = 0;
                break;
            }
        }

        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/mark_story_as_unread', {
                story_id: story_id,
                feed_id: feed_id
            }, null, null, {});
        }
        
        $.isFunction(callback) && callback();
    },
    
    mark_story_as_starred: function(story_id, feed_id, callback) {
        var self = this;
        this.starred_count += 1;
        var story = this.get_story(story_id);
        story.starred = true;
        this.make_request('/reader/mark_story_as_starred', {
            story_id: story_id,
            feed_id:  feed_id
        }, callback);
    },
    
    mark_story_as_unstarred: function(story_id, callback) {
        var self = this;
        this.starred_count -= 1;
        var story = this.get_story(story_id);
        story.starred = false;
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
    
    mark_story_as_shared: function(story_id, feed_id, comments, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                var profiles = _.reject(data.user_profiles, _.bind(function(profile) {
                    return profile.id in this.user_profiles._byId;
                }, this));
                this.user_profiles.add(profiles);
            }
            callback(data);
        }, this);
        
        this.make_request('/social/share_story', {
            story_id: story_id,
            feed_id: feed_id,
            comments: comments
        }, pre_callback, error_callback);
    },
    
    reset_feeds: function() {
        this.feeds = {};
    },
    
    load_feeds: function(callback, error_callback) {
        var self = this;
        
        var pre_callback = function(subscriptions) {
            // NEWSBLUR.log(['subscriptions', subscriptions]);
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
                    if (feed.favicon_fetching) self.flags['favicons_fetching'] = true;
                }
            });
            self.folders = subscriptions.folders;
            self.starred_count = subscriptions.starred_count;
            self.social_feeds.reset(subscriptions.social_feeds);
            self.user_profile.set(subscriptions.social_profile);
            
            if (!_.isEqual(self.favicons, {})) {
                _.each(self.feeds, function(feed) {
                    if (self.favicons[feed.id]) {
                        feed.favicon = self.favicons[feed.id];
                    }
                });
            }
            
            self.detect_any_inactive_feeds();
            callback();
        };
        
        var data = {};
        if (NEWSBLUR.Flags['start_import_from_google_reader']) {
            data['include_favicons'] = true;
        }
        
        this.make_request('/reader/feeds', data, pre_callback, error_callback, {request_type: 'GET'});
    },
    
    detect_any_inactive_feeds: function() {
        this.flags['has_chosen_feeds'] = _.any(this.feeds, function(feed) {
            return feed.active;
        });
    },
    
    load_feeds_flat: function(callback, error_callback) {
        var self = this;
        var data = {
            flat: true,
            include_favicons: true
        };
        
        var pre_callback = function(subscriptions) {
            // NEWSBLUR.log(['subscriptions', subscriptions.flat_folders]);
            var flat_feeds = function(feeds) {
                var flattened = _.flatten(_.map(feeds, _.values));
                return _.flatten(_.map(flattened, function(feed) {
                    if (!_.isNumber(feed) && feed) return flat_feeds(feed);
                    else return feed;
                }));
            };
            var valid_feeds = flat_feeds({'root': subscriptions.flat_folders});

            _.each(subscriptions.feeds, function(feed, feed_id) {
                if (_.contains(valid_feeds, parseInt(feed_id, 10))) {
                    self.feeds[feed_id] = feed;
                    if (feed.favicon_fetching) self.flags['favicons_fetching'] = true;
                }
            });
            self.folders = subscriptions.flat_folders;
            self.starred_count = subscriptions.starred_count;
            
            if (!_.isEqual(self.favicons, {})) {
                _.each(self.feeds, function(feed) {
                    if (self.favicons[feed.id]) {
                        feed.favicon = self.favicons[feed.id];
                    }
                });
            }
            callback();
        };
        
        this.make_request('/reader/feeds', data, pre_callback, error_callback, {request_type: 'GET'});
    },
    
    load_feed_favicons: function(callback, loaded_once, load_all) {
        var pre_callback = _.bind(function(favicons) {
          this.favicons = favicons;
          if (!_.isEqual(this.feeds, {})) {
            _.each(this.feeds, _.bind(function(feed) {
                if (favicons[feed.id]) {
                    feed.favicon = favicons[feed.id];
                }
            }, this));
          }
          callback();
        }, this);
        var data = {
          load_all : load_all
        };
        if (loaded_once) {
          data['feed_ids'] = _.compact(_.map(this.feeds, function(feed) {
            return !feed.favicon && feed.id;
          }));
        }
        this.make_request('/reader/favicons', data, pre_callback, pre_callback, {request_type: 'GET'});
    },
    
    load_feed: function(feed_id, page, first_load, callback, error_callback) {
        var self = this;
        
        var pre_callback = function(data) {
            return self.load_feed_precallback(data, feed_id, callback, first_load);
        };
        
        this.feed_id = feed_id;

        // NEWSBLUR.log(['load_feed', feed_id, page, first_load, callback, pre_callback, this.feeds[feed_id].feed_address]);
        if (feed_id) {
            this.make_request('/reader/feed/'+feed_id,
                {
                    page: page,
                    feed_address: this.feeds[feed_id].feed_address
                }, pre_callback,
                error_callback,
                {
                    'ajax_group': (page > 1 ? 'feed_page' : 'feed'),
                    'request_type': 'GET'
                }
            );
        }
    },
    
    load_feed_precallback: function(data, feed_id, callback, first_load) {
        var self = this;
        
        // NEWSBLUR.log(['load_feed_precallback', feed_id, this.feed_id, this.feed_id == feed_id, first_load]);
        if (data.dupe_feed_id && this.feed_id == data.dupe_feed_id) {
            feed_id = data.dupe_feed_id;
        }
        if (feed_id == this.feed_id) {
            if (data.feeds) {
                _.extend(this.feeds, data.feeds);
            }
            if (data && first_load) {
                this.stories = data.stories;
                this.feed_tags = data.feed_tags || {};
                this.feed_authors = data.feed_authors || {};
                this.feed_id = feed_id;
                if (_.string.include(feed_id, ':')) {
                    _.extend(this.classifiers, data.classifiers);
                } else {
                    this.classifiers[feed_id] = _.extend({}, this.defaults['classifiers'], data.classifiers);
                }
                this.starred_stories = data.starred_stories;
                this.story_keys = {};
                for (var s in data.stories) {
                    this.story_keys[data.stories[s].id] = true;
                }
                if (data.feed_address) {
                  this.feeds[feed_id].feed_address = data.feed_address;
                }
            } else if (data) {
                data.stories = _.select(data.stories, function(story) {
                    if (!self.story_keys[story.id]) {
                        self.stories.push(story);
                        self.story_keys[story.id] = true;
                        return true;
                    }
                });
            }
            if (data.user_profiles) {
                var profiles = _.reject(data.user_profiles, _.bind(function(profile) {
                    return profile.id in this.user_profiles._byId;
                }, this));
                this.user_profiles.add(profiles);
            }
            $.isFunction(callback) && callback(data, first_load);
        }
    },
    
    load_canonical_feed: function(feed_id, callback) {
        var pre_callback = _.bind(function(data) {
            this.feeds[data.id] = data;
            this.feed_tags = data.feed_tags || {};
            this.feed_authors = data.feed_authors || {};
            this.feed_id = feed_id;
            this.classifiers[feed_id] = data.classifiers || this.defaults['classifiers'];
            callback && callback();
        }, this);
        
        this.make_request('/rss_feeds/feed/'+feed_id, {}, pre_callback, $.noop, {request_type: 'GET'});
    },
    
    fetch_starred_stories: function(page, callback, error_callback, first_load) {
        var self = this;
        
        var pre_callback = function(data) {
            return self.load_feed_precallback(data, 'starred', callback, first_load);
        };

        this.feed_id = 'starred';
        
        this.make_request('/reader/starred_stories', {
            page: page
        }, pre_callback, error_callback, {
            'ajax_group': (page ? 'feed_page' : 'feed'),
            'request_type': 'GET'
        });
    },
    
    fetch_river_stories: function(feed_id, feeds, page, callback, error_callback, first_load) {
        var self = this;
        
        if (first_load || !page) this.read_stories_river_count = 0;

        var pre_callback = function(data) {
            return self.load_feed_precallback(data, feed_id, callback, first_load);
        };
        
        this.feed_id = feed_id;

        this.make_request('/reader/river_stories', {
            feeds: feeds,
            page: page,
            read_stories_count: this.read_stories_river_count
        }, pre_callback, error_callback, {
            'ajax_group': (page ? 'feed_page' : 'feed'),
            'request_type': 'GET'
        });
    },
    
    fetch_social_stories: function(feed_id, user_id, page, callback, error_callback, first_load) {
        var self = this;
        
        var pre_callback = function(data) {
            return self.load_feed_precallback(data, feed_id, callback, first_load);
        };
        
        this.feed_id = feed_id;

        this.make_request('/social/stories/'+user_id+'/', {
            page: page
        }, pre_callback, error_callback, {
            'ajax_group': (page > 1 ? 'feed_page' : 'feed'),
            'request_type': 'GET'
        });
    },
    
    get_feeds_trainer: function(feed_id, callback) {
        var self = this;
        var params = {};
        
        if (feed_id) {
          params['feed_id'] = feed_id;
        }
        
        this.make_request('/reader/feeds_trainer', params, callback, null, {'ajax_group': 'feed', 'request_type': 'GET'});
    },    
    
    get_social_trainer: function(feed_id, callback) {
        var self = this;
        var params = {};
        
        if (feed_id) {
          params['user_id'] = feed_id.replace('social:', '');
        }
        
        this.make_request('/social/feed_trainer', params, callback, null, {'ajax_group': 'feed', 'request_type': 'GET'});
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
    
    refresh_feeds: function(callback, has_unfetched_feeds, feed_id, error_callback) {
        var self = this;
        
        var pre_callback = function(data) {
            self.post_refresh_feeds(data, callback);
        };
        
        var data = {};
        if (has_unfetched_feeds) {
            data['check_fetch_status'] = has_unfetched_feeds;
        }
        if (this.flags['favicons_fetching']) {
            var favicons_fetching = _.compact(_.map(this.feeds, function(feed, k) { 
                if (feed.favicon_fetching && feed.active) return k;
            }));
            if (favicons_fetching.length) {
                data['favicons_fetching'] = favicons_fetching;
            } else {
                this.flags['favicons_fetching'] = false;
            }
        }
        if (feed_id) {
            data['feed_id'] = feed_id;
        }
        
        if (NEWSBLUR.Globals.is_authenticated || feed_id) {
            this.make_request('/reader/refresh_feeds', data, pre_callback, error_callback);
        }
    },
    
    post_refresh_feeds: function(data, callback) {
        var updated_feeds = [];

        for (var f in data.feeds) {
            if (!this.feeds[f]) continue;
            var updated = false;
            f = parseInt(f, 10);
            var feed = data.feeds[f];
            var feed_id = feed.id || f;
            if (feed.id && f != feed.id) {
                NEWSBLUR.log(['Dupe feed being refreshed', f, feed.id, this.feeds[f]]);
                this.feeds[feed.id] = this.feeds[f];
            }
            if ((feed['has_exception'] && !this.feeds[feed_id]['has_exception']) ||
                (this.feeds[feed_id]['has_exception'] && !feed['has_exception'])) {
                updated = true;
                this.feeds[feed_id]['has_exception'] = !!feed['has_exception'];
            }
            for (var k in feed) {
                if (this.feeds[feed_id][k] != feed[k]) {
                    // NEWSBLUR.log(['New Feed', this.feeds[feed_id][k], feed[k], f, k]);
                    NEWSBLUR.log(['Different', k, this.feeds[feed_id].feed_title, this.feeds[feed_id][k], feed[k]]);
                    this.feeds[feed_id][k] = feed[k];
                    updated = true;
                }
            }
            if (feed['favicon']) {
                this.feeds[feed_id]['favicon'] = feed['favicon'];
                this.feeds[feed_id]['favicon_color'] = feed['favicon_color'];
                this.feeds[feed_id]['favicon_fetching'] = false;
                updated = true;
            }
            if (updated && !(f in updated_feeds)) {
                updated_feeds.push(f);
            }
        }
        callback(updated_feeds);
    },
    
    refresh_feed: function(feed_id, callback) {
        var self = this;
        
        var pre_callback = function(data) {
            // NEWSBLUR.log(['refresh_feed pre_callback', data]);
            self.load_feed_precallback(data, feed_id, callback);
        };
        
        // NEWSBLUR.log(['refresh_feed', feed_id, page, first_load, callback, pre_callback]);
        if (feed_id) {
            this.make_request('/reader/feed/'+feed_id,
                {
                    page: 0,
                    feed_address: this.feeds[feed_id].feed_address
                }, pre_callback,
                null,
                {
                    'ajax_group': 'feed_page',
                    'request_type': 'GET'
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
    
    set_feed: function(feed) {
        this.feeds[feed.id] = feed;
    },

    add_social_feed: function(feed) {
        var social_feed = this.social_feeds.get(feed);
        if (!social_feed) {
            social_feed = new NEWSBLUR.Models.SocialSubscription(feed.attributes);
            this.social_feeds.add(social_feed);
        }
        return social_feed;
    },
    
    get_feed: function(feed_id) {
        var self = this;
        
        if (_.string.include(feed_id, 'social:')) {
            return this.social_feeds.get(feed_id).attributes;
        } else {
            return this.feeds[feed_id];
        }
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
    
    save_classifier: function(data, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/classifier/save', data, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    get_feed_classifier: function(feed_id, callback) {
        this.make_request('/classifier/'+feed_id, {}, callback, null, {
            'ajax_group': 'feed',
            'request_type': 'GET'
        });
    },
    
    delete_feed: function(feed_id, in_folder, callback, duplicate_feed) {
        if (!duplicate_feed) delete this.feeds[feed_id];
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
        }, callback, function() {
          callback({'message': NEWSBLUR.Globals.is_anonymous ? 'Please create an account. Not much to do without an account.' : 'There was a problem trying to add this site. Please try a different URL.'});
        });
    },
    
    save_add_folder: function(folder, parent_folder, callback) {
        this.make_request('/reader/add_folder/', {
            'folder': folder,
            'parent_folder': parent_folder
        }, callback, function() {
          callback({'message': NEWSBLUR.Globals.is_anonymous ? 'Please create an account. Not much to do without an account.' : 'There was a problem trying to add this folder. Please try a different URL.'});
        });
    },
    
    move_feed_to_folder: function(feed_id, in_folder, to_folder, callback) {
        var pre_callback = _.bind(function(data) {
            this.folders = data.folders;
            return callback();
        }, this);

        this.make_request('/reader/move_feed_to_folder', {
            'feed_id': feed_id,
            'in_folder': in_folder,
            'to_folder': to_folder
        }, pre_callback);
    },
    
    move_folder_to_folder: function(folder_name, in_folder, to_folder, callback) {
        var pre_callback = _.bind(function(data) {
            this.folders = data.folders;
            return callback();
        }, this);

        this.make_request('/reader/move_folder_to_folder', {
            'folder_name': folder_name,
            'in_folder': in_folder,
            'to_folder': to_folder
        }, pre_callback);
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
    
    save_account_settings: function(settings, callback) {
        this.make_request('/profile/set_account_settings', settings, callback, null);
    },
    
    view_setting: function(feed_id, feed_view_setting, callback) {
        if (typeof feed_view_setting == 'undefined') {
            return NEWSBLUR.Preferences.view_settings[feed_id+''] || NEWSBLUR.Preferences.default_view;
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
        
        if (changed) {
            this.make_request('/profile/set_collapsed_folders', {
                'collapsed_folders': $.toJSON(NEWSBLUR.Preferences.collapsed_folders)
            }, callback, null);
        }
    },
    
    save_mark_read: function(days, callback) {
        this.make_request('/reader/mark_all_as_read', {'days': days}, callback);
    },
    
    get_features_page: function(page, callback) {
        this.make_request('/reader/features', {'page': page}, callback, callback, {request_type: 'GET'});
    },
    
    load_recommended_feed: function(page, refresh, unmoderated, callback, error_callback) {
        this.make_request('/recommendations/load_recommended_feed', {
            'page'         : page, 
            'refresh'      : refresh,
            'unmoderated'  : unmoderated
        }, callback, error_callback, {request_type: 'GET'});
    },
    
    approve_feed_in_moderation_queue: function(feed_id, date, callback) {
        this.make_request('/recommendations/approve_feed', {
            'feed_id'     : feed_id,
            'date'        : date,
            'unmoderated' : true
        }, callback, {request_type: 'GET'});
    },
    
    decline_feed_in_moderation_queue: function(feed_id, callback) {
        this.make_request('/recommendations/decline_feed', {
            'feed_id'     : feed_id,
            'unmoderated' : true
        }, callback, {request_type: 'GET'});
    },
    
    load_dashboard_graphs: function(callback, error_callback) {
        this.make_request('/statistics/dashboard_graphs', {}, callback, error_callback, {request_type: 'GET'});
    },
    
    load_feedback_table: function(callback, error_callback) {
        this.make_request('/statistics/feedback_table', {}, callback, error_callback, {request_type: 'GET'});
    },
    
    save_feed_order: function(folders, callback) {
        this.make_request('/reader/save_feed_order', {'folders': $.toJSON(folders)}, callback);
    },
    
    get_feed_statistics: function(feed_id, callback) {
        this.make_request('/rss_feeds/statistics/'+feed_id, {}, callback, callback, {
            'ajax_group': 'statistics',
            'request_type': 'GET'
        });
    },
    
    get_social_statistics: function(social_feed_id, callback) {
        this.make_request('/social/statistics/'+_.string.ltrim(social_feed_id, 'social:'), {}, callback, callback, {
            'ajax_group': 'statistics',
            'request_type': 'GET'
        });
    },
    
    get_feed_recommendation_info: function(feed_id, callback) {
        this.make_request('/recommendations/load_feed_info/'+feed_id, {}, callback, callback, {
            'ajax_group': 'statistics',
            'request_type': 'GET'
        });
    },
    
    get_feed_settings: function(feed_id, callback) {
        this.make_request('/rss_feeds/feed_settings/'+feed_id, {}, callback, callback, {
            'ajax_group': 'statistics',
            'request_type': 'GET'
        });
    },
    
    get_social_settings: function(social_feed_id, callback) {
        this.make_request('/social/settings/'+_.string.ltrim(social_feed_id, 'social:'), {}, callback, callback, {
            'ajax_group': 'statistics',
            'request_type': 'GET'
        });
    },
    
    start_import_from_google_reader: function(callback) {
        this.make_request('/import/import_from_google_reader/', {}, callback);
    },
    
    save_recommended_site: function(data, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/recommendations/save_recommended_feed', data, callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    save_exception_retry: function(feed_id, callback, error_callback) {
        var self = this;
        
        var pre_callback = function(data) {
            // NEWSBLUR.log(['refresh_feed pre_callback', data]);
            self.post_refresh_feeds(data, callback);
        };
        
        this.make_request('/rss_feeds/exception_retry', {
          'feed_id': feed_id, 
          'reset_fetch': !!(this.feeds[feed_id].has_feed_exception || this.feeds[feed_id].has_page_exception)
        }, pre_callback, error_callback);
    },
        
    save_exception_change_feed_link: function(feed_id, feed_link, callback) {
        var self = this;
        
        var pre_callback = function(data) {
            // NEWSBLUR.log(['save_exception_change_feed_link pre_callback', feed_id, feed_link, data]);
            self.post_refresh_feeds(data, callback);
            NEWSBLUR.reader.force_feed_refresh(feed_id, data.new_feed_id);
        };
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/rss_feeds/exception_change_feed_link', {
                'feed_id': feed_id,
                'feed_link': feed_link
            }, pre_callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
        
    save_exception_change_feed_address: function(feed_id, feed_address, callback) {
        var self = this;
        
        var pre_callback = function(data) {
            // NEWSBLUR.log(['save_exception_change_feed_address pre_callback', feed_id, feed_address, data]);
            self.post_refresh_feeds(data, callback);
            NEWSBLUR.reader.force_feed_refresh(feed_id, data.new_feed_id);
        };
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/rss_feeds/exception_change_feed_address', {
                'feed_id': feed_id,
                'feed_address': feed_address
            }, pre_callback);
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
    },
    
    send_story_email: function(data, callback, error_callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
          this.make_request('/reader/send_story_email', data, callback, error_callback, {'timeout': 6000});
        } else {
          callback({'code': -1, 'message': 'You must be logged in to send a story over email.'});
        }
    },
    
    load_tutorial: function(data, callback) {
      this.make_request('/reader/load_tutorial', data, callback);
    },
    
    fetch_friends: function(callback) {
        var pre_callback = _.bind(function(data) {
            this.user_profile = new NEWSBLUR.Models.User(data.user_profile);
            this.follower_profiles = new NEWSBLUR.Collections.Users(data.follower_profiles);
            this.following_profiles = new NEWSBLUR.Collections.Users(data.following_profiles);
            callback(data);
        }, this);
        this.make_request('/social/friends', null, pre_callback);
    },
    
    fetch_user_profile: function(user_id, callback) {
        this.make_request('/social/profile', {'user_id': user_id}, callback, callback, {request_type: 'GET'});
    },
    
    search_for_friends: function(query, callback) {
        this.make_request('/social/find_friends', {'query': query}, callback, callback, {request_type: 'GET'});
    },
    
    disconnect_social_service: function(service, callback) {
        this.make_request('/social/'+service+'_disconnect/', null, callback);
    },
    
    save_user_profile: function(data, callback) {
        this.make_request('/social/profile/', data, callback);
    },
    
    follow_user: function(user_id, callback) {
        var pre_callback = _.bind(function(data) {
            console.log(["follow data", data]);
            this.user_profile.set(data.user_profile);
            var following_profile = this.following_profiles.detect(function(profile) {
                return profile.get('user_id') == data.follow_profile.user_id;
            });
            var follow_user;
            if (following_profile) {
                follow_user = following_profile.set(data.follow_profile);
            } else {
                this.following_profiles.add(data.follow_profile);
                follow_user = new NEWSBLUR.Models.User(data.follow_profile);
            }
            this.social_feeds.remove(data.follow_subscription);
            this.social_feeds.add(data.follow_subscription);
            callback(data, follow_user);
        }, this);
        this.make_request('/social/follow', {'user_id': user_id}, pre_callback);
    },
    
    unfollow_user: function(user_id, callback) {
        var pre_callback = _.bind(function(data) {
            this.user_profile.set(data.user_profile);
            this.following_profiles.remove(function(profile) {
                return profile.get('user_id') == data.unfollow_profile.user_id;
            });
            this.social_feeds.remove(data.unfollow_profile.id);
            var unfollow_user = new NEWSBLUR.Models.User(data.unfollow_profile);
            callback(data, unfollow_user);
        }, this);
        this.make_request('/social/unfollow', {'user_id': user_id}, pre_callback);
    },
    
    load_public_story_comments: function(story_id, feed_id, callback) {
        this.make_request('/social/comments', {
            'story_id': story_id,
            'feed_id': feed_id
        }, callback, callback, {request_type: 'GET'});
    },
    
    recalculate_story_scores: function(feed_id) {
        _.each(this.stories, _.bind(function(story, i) {
            if (story.story_feed_id != feed_id) return;
            this.stories[i].intelligence.title = 0;
            _.each(this.classifiers[feed_id].titles, _.bind(function(classifier_score, classifier_title) {
                if (this.stories[i].intelligence.title <= 0 && 
                    story.story_title && story.story_title.indexOf(classifier_title) != -1) {
                    this.stories[i].intelligence.title = classifier_score;
                }
            }, this));
            
            this.stories[i].intelligence.author = 0;
            _.each(this.classifiers[feed_id].authors, _.bind(function(classifier_score, classifier_author) {
                if (this.stories[i].intelligence.author <= 0 && 
                    story.story_authors && story.story_authors.indexOf(classifier_author) != -1) {
                    this.stories[i].intelligence.author = classifier_score;
                }
            }, this));
            
            this.stories[i].intelligence.tags = 0;
            _.each(this.classifiers[feed_id].tags, _.bind(function(classifier_score, classifier_tag) {
                if (this.stories[i].intelligence.tags <= 0 && 
                    story.story_tags && _.contains(story.story_tags, classifier_tag)) {
                    this.stories[i].intelligence.tags = classifier_score;
                }
            }, this));
            
            this.stories[i].intelligence.feed = 0;
            _.each(this.classifiers[feed_id].feeds, _.bind(function(classifier_score, classifier_feed_id) {
                if (this.stories[i].intelligence.feed <= 0 && 
                    story.story_feed_id == classifier_feed_id) {
                    this.stories[i].intelligence.feed = classifier_score;
                }
            }, this));
        }, this));
    }

};


