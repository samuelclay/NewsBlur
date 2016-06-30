NEWSBLUR.AssetModel = Backbone.Router.extend({

    initialize: function() {
        this.defaults = {
            classifiers: {
                titles: {},
                tags: {},
                authors: {},
                feeds: {}
            }
        };
        this.feeds = new NEWSBLUR.Collections.Feeds();
        this.social_feeds = new NEWSBLUR.Collections.SocialSubscriptions();
        this.folders = new NEWSBLUR.Collections.Folders([]);
        this.favicons = {};
        this.stories = new NEWSBLUR.Collections.Stories();
        this.starred_feeds = new NEWSBLUR.Collections.StarredFeeds();
        this.queued_read_stories = {};
        this.classifiers = {};
        this.friends = {};
        this.profile = {};
        this.user_profile = new NEWSBLUR.Models.User();
        this.social_services = {};
        this.user_profiles = new NEWSBLUR.Collections.Users();
        this.follower_profiles = new NEWSBLUR.Collections.Users();
        this.following_profiles = new NEWSBLUR.Collections.Users();
        this.starred_stories = [];
        this.starred_count = 0;
        this.flags = {
            'favicons_fetching': false,
            'has_chosen_feeds': false,
            'no_more_stories': false
        };

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
        this.ajax['interactions']  = $.manageAjax.create('interactions', {queue: 'clear', abortOld: true}); 
        $.ajaxSettings.traditional = true;
    },
    
    make_request: function(url, data, callback, error_callback, options) {
        var self = this;
        var options = $.extend({
            'ajax_group': 'queue',
            'traditional': true,
            'domSuccessTrigger': true,
            'preventDoubleRequests': false,
            'timeout': 15000,
            'retry': true
        }, options);
        var request_type = options.request_type || 'POST';
        var clear_queue = false;
        
        if (options['ajax_group'] == 'feed') {
            clear_queue = true;
        }
        if (options['ajax_group'] == 'statistics') {
            clear_queue = true;
        }
        if (options['ajax_group'] == 'interactions') {
            clear_queue = true;
        }
        
        if (clear_queue) {
            this.ajax[options['ajax_group']].clear(true);
        }
        if (request_type == 'GET') {
            var params = data && $.toJSON(data);
            if (params && params.length > 2000) {
                request_type = 'POST';
            }
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
                if (errorThrown == 'abort') {
                    return;
                }
                NEWSBLUR.log(['AJAX Error', e, e.status, textStatus, errorThrown, 
                              !!error_callback, error_callback, $.isFunction(callback)]);
                
                if (options.retry) {
                    NEWSBLUR.log(['Retrying...', url, data, !!callback, !!error_callback, options]);
                    options.retry = false;
                    self.make_request(url, data, callback, error_callback, options);
                    return;
                }
                if (errorThrown == "timeout") textStatus = "NewsBlur timed out trying<br />to connect. Just try again.";
                if (error_callback) {
                    error_callback(e, textStatus, errorThrown);
                } else if ($.isFunction(callback)) {
                    var message = "Please create an account. Not much<br />to do without an account.";
                    if (NEWSBLUR.Globals.is_authenticated) {
                      message = "Sorry, there was an unhandled error.";
                    }
                    callback({'message': message, status_code: e.status});
                }
            }
        }, options)); 
        
    },
    
    mark_story_as_read: function(story, feed, callback) {
        var self = this;
        var read = story.get('read_status');
        
        if (!story.get('read_status')) {
            story.set('read_status', 1);
            
            if (NEWSBLUR.Globals.is_authenticated) {
                if (!(feed.id in this.queued_read_stories)) { this.queued_read_stories[feed.id] = []; }
                this.queued_read_stories[feed.id].push(story.id);
                // NEWSBLUR.log(['Marking Read', this.queued_read_stories, story.id]);
            
                this.make_request('/reader/mark_story_as_read', {
                    story_id: this.queued_read_stories[feed.id],
                    feed_id: feed.id
                }, null, null, {
                    'ajax_group': 'queue_clear',
                    'beforeSend': function() {
                        self.queued_read_stories = {};
                    }
                });
            }
        }
        
        $.isFunction(callback) && callback(read);
    },
    
    mark_story_hash_as_read: function(story, callback) {
        var self = this;
        var read = story.get('read_status');
        
        if (!story.get('read_status')) {
            story.set('read_status', 1);
            
            if (NEWSBLUR.Globals.is_authenticated) {
                if (!('hashes' in this.queued_read_stories)) { this.queued_read_stories['hashes'] = []; }
                this.queued_read_stories['hashes'].push(story.get('story_hash'));
                // NEWSBLUR.log(['Marking Read', this.queued_read_stories, story.id]);
            
                this.make_request('/reader/mark_story_hashes_as_read', {
                    story_hash: this.queued_read_stories['hashes']
                }, null, null, {
                    'ajax_group': 'queue_clear',
                    'beforeSend': function() {
                        self.queued_read_stories = {};
                    }
                });
            }
        }
        
        $.isFunction(callback) && callback(read);
    },
    
    mark_social_story_as_read: function(story, social_feed, callback) {
        var self = this;
        var feed_id = story.get('story_feed_id');
        var social_user_id = social_feed && social_feed.get('user_id');
        if (!social_user_id) {
            social_user_id = story.get('friend_user_ids')[0];
        }
        if (!social_user_id) {
            social_user_id = story.get('public_user_ids')[0];
        }
        var read = story.get('read_status');

        if (!story.get('read_status')) {
            story.set('read_status', 1);
            
            if (NEWSBLUR.Globals.is_authenticated) {
                if (!(social_user_id in this.queued_read_stories)) { 
                    this.queued_read_stories[social_user_id] = {};
                }
                if (!(feed_id in this.queued_read_stories[social_user_id])) {
                    this.queued_read_stories[social_user_id][feed_id] = [];
                }
                this.queued_read_stories[social_user_id][feed_id].push(story.id);
                // NEWSBLUR.log(['Marking Read', this.queued_read_stories, story.id]);
            
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
        
        $.isFunction(callback) && callback(read);
    },
    
    mark_story_as_unread: function(story_id, feed_id, callback, error_callback) {
        var self = this;
        var read = true;
        var story = this.get_story(story_id);
        story.set('read_status', 0);

        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/mark_story_hash_as_unread', {
                story_hash: story.get('story_hash'),
                story_id: story_id,
                feed_id: feed_id
            }, null, error_callback, {});
        }
        
        $.isFunction(callback) && callback();
    },
    
    mark_story_as_starred: function(story_id, callback) {
        var self = this;
        var story = this.get_story(story_id);
        var selected = this.starred_feeds.selected();
        
        var pre_callback = function(data) {
            if (data.starred_counts) {
                self.starred_feeds.reset(data.starred_counts, {parse: true});
                var feed = self.get_feed(story.get('story_feed_id'));
                if (feed && feed.views) _.invoke(feed.views, 'render');
            }
            
            if (selected) {
                self.starred_feeds.get(selected).set('selected', true);
            }
            
            if (callback) callback(data);
        };

        this.make_request('/reader/mark_story_hash_as_starred', {
            story_hash: story.get('story_hash'),
            user_tags: story.get('user_tags')
        }, pre_callback);
    },
    
    mark_story_as_unstarred: function(story_id, callback) {
        var self = this;
        var story = this.get_story(story_id);
        var selected = this.starred_feeds.selected();

        var pre_callback = function(data) {
            if (data.starred_counts) { 
                self.starred_feeds.reset(data.starred_counts, {parse: true, update: true});
                var feed = self.get_feed(story.get('story_feed_id'));
                if (feed && feed.views) _.invoke(feed.views, 'render');
            }
            
            if (selected && self.starred_feeds.get(selected)) {
                self.starred_feeds.get(selected).set('selected', true);
            }
            
            if (callback) callback(data);
        };

        this.make_request('/reader/mark_story_hash_as_unstarred', {
            story_hash: story.get('story_hash')
        }, pre_callback);
    },
    
    mark_feed_as_read: function(feed_id, cutoff_timestamp, direction, mark_active, callback) {
        var self = this;
        var feed_ids = _.isArray(feed_id) 
                       ? _.select(feed_id, function(f) { return f; })
                       : [feed_id];
        
        this.make_request('/reader/mark_feed_as_read', {
            feed_id: feed_ids,
            cutoff_timestamp: cutoff_timestamp,
            direction: direction
        }, callback);
        
        _.each(feed_ids, function(feed_id) {
            var feed = self.get_feed(feed_id);
            if (!feed) return;
            feed.set({'ps': 0, 'nt': 0, 'ng': 0});
        });
        if (mark_active) {
            this.stories.each(function(story) {
                if ((!direction || direction == "older") && 
                    cutoff_timestamp && 
                    parseInt(story.get('story_timestamp'), 10) > cutoff_timestamp) {
                    return;
                } else if (direction == "newer" && 
                    cutoff_timestamp && 
                    parseInt(story.get('story_timestamp'), 10) < cutoff_timestamp) {
                    return;
                }
                story.set('read_status', true);
            });
        }
    },
    
    mark_story_as_shared: function(params, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            var story = this.get_story(params.story_id);
            story.set(data.story);
            callback(data);
        }, this);

        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/social/share_story', {
                story_id: params.story_id,
                feed_id: params.story_feed_id,
                comments: params.comments,
                source_user_id: params.source_user_id,
                relative_user_id: params.relative_user_id,
                post_to_services: params.post_to_services
            }, pre_callback, error_callback);
        } else {
            error_callback();
        }
    },
    
    mark_story_as_unshared: function(params, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            var story = this.get_story(params.story_id);
            story.set(data.story);
            callback(data);
        }, this);
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/social/unshare_story', {
                story_id: params.story_id,
                feed_id: params.story_feed_id,
                relative_user_id: params.relative_user_id
            }, pre_callback, error_callback);
        } else {
            error_callback();
        }
    },
    
    save_comment_reply: function(story_id, story_feed_id, comment_user_id, reply_comments, reply_id, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            callback(data);
        }, this);
        
        this.make_request('/social/save_comment_reply', {
            story_id: story_id,
            story_feed_id: story_feed_id,
            comment_user_id: comment_user_id,
            reply_comments: reply_comments,
            reply_id: reply_id
        }, pre_callback, error_callback);
    },
    
    delete_comment_reply: function(story_id, story_feed_id, comment_user_id, reply_id, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            callback(data);
        }, this);
        
        this.make_request('/social/remove_comment_reply', {
            story_id: story_id,
            story_feed_id: story_feed_id,
            comment_user_id: comment_user_id,
            reply_id: reply_id
        }, pre_callback, error_callback);
    },
    
    like_comment: function(story_id, story_feed_id, comment_user_id, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            callback && callback(data);
        }, this);
        
        this.make_request('/social/like_comment', {
            story_id: story_id,
            story_feed_id: story_feed_id,
            comment_user_id: comment_user_id
        }, pre_callback, error_callback);
    },
    
    remove_like_comment: function(story_id, story_feed_id, comment_user_id, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            callback && callback(data);
        }, this);
        
        this.make_request('/social/remove_like_comment', {
            story_id: story_id,
            story_feed_id: story_feed_id,
            comment_user_id: comment_user_id
        }, pre_callback, error_callback);
    },
    
    add_user_profiles: function(user_profiles) {
        var profiles = _.reject(user_profiles, _.bind(function(profile) {
            return profile.id in this.user_profiles._byId;
        }, this));
        this.user_profiles.add(profiles);
    },
    
    load_feeds: function(callback, error_callback) {
        var self = this;
        var selected = this.feeds.selected();

        var pre_callback = function(feeds, subscriptions) {
            self.flags['favicons_fetching'] = self.feeds.any(function(feed) { return feed.get('favicons_fetching'); });

            self.folders.reset(_.compact(subscriptions.folders), {parse: true});
            self.starred_count = subscriptions.starred_count;
            self.starred_feeds.reset(subscriptions.starred_counts, {parse: true});
            self.social_feeds.reset(subscriptions.social_feeds, {parse: true});
            self.user_profile.set(subscriptions.social_profile);
            self.social_services = subscriptions.social_services;
            
            if (selected && self.feeds.get(selected)) {
                self.feeds.get(selected).set('selected', true);
            }
            if (!_.isEqual(self.favicons, {})) {
                self.feeds.each(function(feed) {
                    if (self.favicons[feed.id]) {
                        feed.set('favicon', self.favicons[feed.id]);
                    }
                });
            }
            
            self.flags['has_chosen_feeds'] = self.feeds.has_chosen_feeds();
            
            self.feeds.trigger('reset');
            
            callback && callback();
        };
        
        this.feeds.fetch({
            success: pre_callback,
            error: error_callback
        });
    },
    
    load_feed_favicons: function(callback, loaded_once, load_all) {
        var pre_callback = _.bind(function(favicons) {
          this.favicons = favicons;
          if (!_.isEqual(this.feeds, {})) {
            this.feeds.each(function(feed) {
                if (favicons[feed.id]) {
                    feed.set('favicon', favicons[feed.id]);
                }
            });
          }
          callback();
        }, this);
        var data = {
          load_all : load_all
        };
        if (loaded_once) {
          data['feed_ids'] = _.compact(this.feeds.map(function(feed) {
            return !feed.get('favicon') && feed.id;
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

        if (feed_id) {
            this.make_request('/reader/feed/'+feed_id,
                {
                    page: page,
                    feed_address: this.feeds.get(feed_id).get('feed_address'),
                    order: this.view_setting(feed_id, 'order'),
                    read_filter: this.view_setting(feed_id, 'read_filter'),
                    query: NEWSBLUR.reader.flags.search,
                    include_hidden: true
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
        
        if (data.dupe_feed_id && this.feed_id == data.dupe_feed_id) {
            feed_id = data.dupe_feed_id;
        }
        if (feed_id == this.feed_id) {
            if (data.feeds) {
                var river = _.any(['river:', 'social:'], function(prefix) { 
                    return _.isString(feed_id) && _.string.startsWith(feed_id, prefix);
                });
                if (river) _.each(data.feeds, function(feed) { feed.temp = true; });
                this.feeds.add(data.feeds);
            }
            if (data.classifiers) {
                if (_.string.include(feed_id, ':')) { // is_river or is_social
                    _.extend(this.classifiers, data.classifiers);
                } else {
                    this.classifiers[feed_id] = _.extend({}, this.defaults['classifiers'], data.classifiers);
                }
            }
            
            if (data.user_profiles) {
                var profiles = _.reject(data.user_profiles, _.bind(function(profile) {
                    return profile.id in this.user_profiles._byId;
                }, this));
                this.user_profiles.add(profiles);
            }
            
            if (data.updated) {
                var feed = this.get_feed(feed_id);
                feed.set('updated', data.updated);
            }
            
            if (data.stories && first_load) {
                this.feed_tags = data.feed_tags || {};
                this.feed_authors = data.feed_authors || {};
                this.active_feed = this.get_feed(feed_id);
                if (this.active_feed) {
                    this.active_feed.set({
                        feed_title: data.feed_title || this.active_feed.get('feed_title'),
                        updated: data.updated || this.active_feed.get('updated'),
                        feed_address: data.feed_address || this.active_feed.get('feed_address')
                    });
                }
                this.feed_id = feed_id;
                this.starred_stories = data.starred_stories;
                this.stories.reset(data.stories, {added: data.stories.length});
            } else if (data.stories) {
                this.stories.add(data.stories, {silent: true});
                this.stories.trigger('add', {added: data.stories.length});
            }
            
            if (data.stories && !data.stories.length) {
                this.flags['no_more_stories'] = true;
                this.stories.trigger('no_more_stories');
            }
            var attrs = {};
            var feed_attrs = ["num_subscribers", "is_push", "min_to_decay", "favicon_color", "favicon_border", "favicon_fade", "favicon_textg_color", "updated_seconds_ago"];
            for (var attr in feed_attrs) {
                var feed_attr = feed_attrs[attr];
                if (data[feed_attr] || !_.isUndefined(data[feed_attr])) {
                    attrs[feed_attr] = data[feed_attr];
                }
            }
            if (this.active_feed) this.active_feed.set(attrs);

            $.isFunction(callback) && callback(data, first_load);
        }
    },
    
    load_canonical_feed: function(feed_id, callback) {
        var pre_callback = _.bind(function(data) {
            var feed = this.feeds.get(data.id);
            if (feed) {
                feed.set(data);
            } else {
                this.feeds.add(data);
            }
            this.feed_tags = data.feed_tags || {};
            this.feed_authors = data.feed_authors || {};
            this.feed_id = feed_id;
            this.classifiers[feed_id] = data.classifiers || this.defaults['classifiers'];
            callback && callback();
        }, this);
        
        this.make_request('/rss_feeds/feed/'+feed_id, {}, pre_callback, $.noop, {
            request_type: 'GET'
        });
    },
    
    fetch_starred_stories: function(page, tag, callback, error_callback, first_load) {
        var self = this;
        
        var pre_callback = function(data) {
            return self.load_feed_precallback(data, 'starred', callback, first_load);
        };

        this.feed_id = 'starred';
        
        this.make_request('/reader/starred_stories', {
            page: page,
            query: NEWSBLUR.reader.flags.search,
            order: this.view_setting('starred', 'order'),
            tag: tag,
            v: 2
        }, pre_callback, error_callback, {
            'ajax_group': (page ? 'feed_page' : 'feed'),
            'request_type': 'GET'
        });
    },

    fetch_read_stories: function(page, callback, error_callback, first_load) {
        var self = this;
        
        var pre_callback = function(data) {
            if (!NEWSBLUR.Globals.is_premium && NEWSBLUR.Globals.is_authenticated) {
                if (first_load) {
                    data.stories = data.stories.splice(0, 3);
                } else {
                    data.stories = [];
                }
            }
            return self.load_feed_precallback(data, 'read', callback, first_load);
        };

        this.feed_id = 'read';
        
        this.make_request('/reader/read_stories', {
            page: page,
            query: NEWSBLUR.reader.flags.search,
            order: this.view_setting('read', 'order')
        }, pre_callback, error_callback, {
            'ajax_group': (page ? 'feed_page' : 'feed'),
            'request_type': 'GET'
        });
    },
    
    fetch_river_stories: function(feed_id, feeds, page, callback, error_callback, first_load) {
        var self = this;
        
        var pre_callback = function(data) {
            if (!NEWSBLUR.Globals.is_premium && NEWSBLUR.Globals.is_authenticated) {
                if (first_load) {
                    data.stories = data.stories.splice(0, 3);
                } else {
                    data.stories = [];
                }
            }
            self.load_feed_precallback(data, feed_id, callback, first_load);
        };
        
        this.feed_id = feed_id;

        this.make_request('/reader/river_stories', {
            feeds: feeds,
            page: page,
            order: this.view_setting(feed_id, 'order'),
            read_filter: this.view_setting(feed_id, 'read_filter'),
            query: NEWSBLUR.reader.flags.search,
            include_hidden: true
        }, pre_callback, error_callback, {
            'ajax_group': (page ? 'feed_page' : 'feed'),
            'request_type': 'GET'
        });
    },
    
    fetch_river_blurblogs_stories: function(feed_id, page, options, callback, error_callback, first_load) {
        var self = this;
        
        var pre_callback = function(data) {
            self.load_feed_precallback(data, feed_id, callback, first_load);
        };
        
        this.feed_id = feed_id;

        this.make_request('/social/river_stories', {
            page: page,
            order: this.view_setting(feed_id, 'order'),
            global_feed: options.global,
            read_filter: this.view_setting(feed_id, 'read_filter')
        }, pre_callback, error_callback, {
            'ajax_group': (page ? 'feed_page' : 'feed'),
            'request_type': 'GET'
        });
    },
    
    fetch_social_stories: function(feed_id, page, callback, error_callback, first_load) {
        var self = this;
        
        var pre_callback = function(data) {
            return self.load_feed_precallback(data, feed_id, callback, first_load);
        };
        
        this.feed_id = feed_id;
        var user_id = this.get_feed(feed_id).get('user_id');

        this.make_request('/social/stories/'+user_id+'/', {
            page: page,
            order: this.view_setting(feed_id, 'order'),
            read_filter: this.view_setting(feed_id, 'read_filter'),
            query: NEWSBLUR.reader.flags.search
        }, pre_callback, error_callback, {
            'ajax_group': (page > 1 ? 'feed_page' : 'feed'),
            'request_type': 'GET'
        });
    },
    
    fetch_story_changes: function(story_hash, show_changes, callback, error_callback) {
        this.make_request('/rss_feeds/story_changes', {
            story_hash: story_hash,
            show_changes: show_changes
        }, callback, error_callback, {
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
            self.post_refresh_feeds(data, callback, {
                'refresh_feeds': true
            });
        };
        
        var data = {};
        if (has_unfetched_feeds) {
            data['check_fetch_status'] = has_unfetched_feeds;
        }
        if (this.flags['favicons_fetching']) {
            var favicons_fetching = _.pluck(this.feeds.select(function(feed, k) { 
                return feed.get('favicon_fetching') && feed.get('active');
            }), 'id');
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
    
    feed_unread_count: function(feed_id, callback, error_callback) {
        var self = this;
        
        var pre_callback = function(data) {
            self.post_refresh_feeds(data, callback, {
                'refresh_feeds': false
            });
        };
        
        if (NEWSBLUR.Globals.is_authenticated || feed_id) {
            this.make_request('/reader/feed_unread_count',  {
                'feed_id': feed_id
            }, pre_callback, error_callback);
        }
    },
    
    post_refresh_feeds: function(data, callback, options) {
        if (!data.feeds) return;
        
        options = options || {};
        
        _.each(data.feeds, _.bind(function(feed, feed_id) {
            var existing_feed = this.feeds.get(feed_id);
            if (!existing_feed) {
                console.log(["Trying to refresh unsub feed", feed_id, feed]);
                return;
            }
            var feed_id = feed.id || feed_id;
            
            if (feed.id && feed_id != feed.id) {
                NEWSBLUR.log(['Dupe feed being refreshed', feed_id, feed.id, this.feeds.get(f), feed]);
                this.feeds.get(feed.id).set(feed);
            }
            if ((feed['has_exception'] && !existing_feed.get('has_exception')) ||
                (existing_feed.get('has_exception') && !feed['has_exception'])) {
                existing_feed.set('has_exception', !!feed['has_exception']);
            }
            if (feed['favicon'] && existing_feed.get('favicon') != feed['favicon']) {
                existing_feed.set({
                    'favicon': feed['favicon'],
                    'favicon_color': feed['favicon_color'],
                    'favicon_fetching': false
                });
            }
            
            if (existing_feed.get('selected') && options.refresh_feeds) {
                existing_feed.force_update_counts();
            } else {
                existing_feed.set(feed, options);
            }
        }, this));
        
        _.each(data.social_feeds, _.bind(function(feed) {
            var social_feed = this.social_feeds.get(feed.id);
            if (!social_feed) return;
            
            social_feed.set(feed);
        }, this));
        
        callback && callback(data);
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
                    feed_address: this.feeds.get(feed_id).get('feed_address')
                }, pre_callback,
                null,
                {
                    'ajax_group': 'feed_page',
                    'request_type': 'GET'
                }
            );
        }
    },
    
    interactions_count: function(callback, error_callback) {
        this.make_request('/reader/interactions_count', {}, callback, error_callback, {
            'request_type': 'GET'
        });
    },
    
    count_unfetched_feeds: function() {
        var counts = this.feeds.reduce(function(counts, feed) {
            if (feed.get('active')) {
                if (feed.get('fetched_once') || feed.get('has_exception')) {
                    counts['fetched_feeds'] += 1;
                } else {
                    counts['unfetched_feeds'] += 1;
                }
            }
            return counts;
        }, {
            'unfetched_feeds': 0,
            'fetched_feeds': 0
        });
        
        return counts;
    },
    
    unfetched_feeds: function() {
        return this.feeds.filter(function(feed) {
            return feed.get('active') && !feed.get('fetched_once') && !feed.get('has_exception');
        });
    },
    
    set_feed: function(feed_id, feed) {
        if (!feed) {
            feed = feed_id;
            feed_id = feed.id;
        }
        if (!this.feeds.get(feed)) {
            this.feeds.add(feed);
        } else {
            this.feeds.get(feed_id).set(feed);
        }
        
        return this.feeds.get(feed_id);
    },

    add_social_feed: function(feed) {
        var social_feed = this.social_feeds.get(feed);
        if (!social_feed) {
            var attributes = feed.attributes;
            if (!attributes) attributes = feed;
            social_feed = new NEWSBLUR.Models.SocialSubscription(attributes);
            this.social_feeds.add(social_feed);
        }
        return social_feed;
    },
    
    get_feed: function(feed_id) {
        var self = this;
        
        if (_.string.startsWith(feed_id, 'social:')) {
            return this.social_feeds.get(feed_id);
        } else if (_.string.startsWith(feed_id, 'starred:')) {
            return this.starred_feeds.get(feed_id);
        } else {
            return this.feeds.get(feed_id);
        }
    },
    
    get_friend_feeds: function(story) {
        var shares = story.get('shared_by_friends') || [];
        var comments = story.get('commented_by_friends') || [];
        var friend_user_ids = shares.concat(comments);
        return _.map(friend_user_ids, _.bind(function(user_id) { 
            return this.social_feeds.get('social:'+user_id); 
        }, this));
    },
    
    get_feeds: function() {
        var self = this;
        
        return this.feeds;
    },
    
    get_social_feeds: function() {
        var self = this;
        
        return this.social_feeds;
    },
    
    get_starred_feeds: function() {
        var self = this;
        
        return this.starred_feeds;
    },
    
    get_folders: function() {
        var self = this;
        
        return this.folders;
    },
    
    get_folder: function(folder_name) {
        return this.folders.find_folder(folder_name.toLowerCase());
    },
    
    get_feed_tags: function() {
        return this.feed_tags;
    },
    
    get_feed_authors: function() {
        return this.feed_authors;
    },
    
    get_story: function(story_id) {
        var self = this;
        return this.stories.get(story_id);
    },
    
    get_user: function(user_id) {
        var user = this.user_profiles.find(user_id);
        if (!user && user_id == this.user_profile.get('user_id')) {
            user = this.profile;
        }
        
        return user;
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
    
    delete_feed: function(feed_id, in_folder, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/delete_feed', {
                'feed_id': feed_id, 
                'in_folder': in_folder
            }, callback, null);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    delete_feeds_by_folder: function(feeds_by_folder, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            _.each(feeds_by_folder, _.bind(function(feed_in_folder) {
                this.feeds.remove(feed_in_folder[0]);
            }, this));
            this.folders.reset(_.compact(data.folders), {parse: true});
            return callback();
        }, this);

        this.make_request('/reader/delete_feeds_by_folder', {
            'feeds_by_folder': $.toJSON(feeds_by_folder)
        }, pre_callback, error_callback);
    },
    
    delete_feed_by_url: function(url, in_folder, callback) {
        this.make_request('/reader/delete_feed_by_url/', {
            'url': url,
            'in_folder': in_folder || ''
        }, callback, function() {
          callback({'message': NEWSBLUR.Globals.is_anonymous ? 'Please create an account. Not much to do without an account.' : 'There was a problem trying to add this site. Please try a different URL.'});
        });
    },
    
    delete_folder: function(folder_name, in_folder, feeds, callback) {
        var self = this;
        var pre_callback = function(data) {
            self.folders.reset(_.compact(data.folders), {parse: true});
            self.feeds.trigger('reset');

            callback(data);
        };
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/delete_folder', {
                'folder_name': folder_name,
                'in_folder': in_folder,
                'feed_id': feeds
            }, pre_callback, null);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    rename_feed: function(feed_id, feed_title, callback) {
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
    
    save_add_url: function(url, folder, callback, options) {
        options = _.extend({'auto_active': true}, options);
        this.make_request('/reader/add_url/', {
            'url': url,
            'folder': folder,
            'auto_active': options.auto_active
        }, callback, function(data) {
          callback({'message': NEWSBLUR.Globals.is_anonymous ? 'Please create an account. Not much to do without an account.' : data.message || 'There was a problem trying to add this site. Please try a different URL.'});
        });
    },
    
    save_add_folder: function(folder, parent_folder, callback) {
        this.make_request('/reader/add_folder/', {
            'folder': folder,
            'parent_folder': parent_folder
        }, callback, function(data) {
          callback({'message': NEWSBLUR.Globals.is_anonymous ? 'Please create an account. Not much to do without an account.' : data.message || 'There was a problem trying to add this folder.'});
        });
    },
    
    move_feed_to_folder: function(feed_id, in_folder, to_folder, callback) {
        var pre_callback = _.bind(function(data) {
            this.folders.reset(_.compact(data.folders), {parse: true});
            return callback();
        }, this);

        this.make_request('/reader/move_feed_to_folder', {
            'feed_id': feed_id,
            'in_folder': in_folder,
            'to_folder': to_folder
        }, pre_callback);
    },
    
    move_feed_to_folders: function(feed_id, in_folders, to_folders, callback) {
        var pre_callback = _.bind(function(data) {
            this.folders.reset(_.compact(data.folders), {parse: true});
            return callback();
        }, this);

        this.make_request('/reader/move_feed_to_folders', {
            'feed_id': feed_id,
            'in_folders': in_folders,
            'to_folders': to_folders
        }, pre_callback);
    },
    
    move_folder_to_folder: function(folder_name, in_folder, to_folder, callback) {
        var pre_callback = _.bind(function(data) {
            this.folders.reset(_.compact(data.folders), {parse: true});
            return callback();
        }, this);

        this.make_request('/reader/move_folder_to_folder', {
            'folder_name': folder_name,
            'in_folder': in_folder,
            'to_folder': to_folder
        }, pre_callback);
    },
    
    move_feeds_by_folder: function(feeds_by_folder, to_folder, new_folder, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            this.folders.reset(_.compact(data.folders), {parse: true});
            return callback();
        }, this);

        this.make_request('/reader/move_feeds_by_folder_to_folder', {
            'feeds_by_folder': $.toJSON(feeds_by_folder),
            'to_folder': to_folder,
            'new_folder': new_folder
        }, pre_callback, error_callback);
    },
    
    preference: function(preference, value, callback) {
        if (typeof value == 'undefined') {
            var pref = NEWSBLUR.Preferences[preference];
            if ((/^\d+$/).test(pref)) return parseInt(pref, 10);
            return pref;
        }
        
        if (NEWSBLUR.Preferences[preference] == value) {
          return $.isFunction(callback) && callback();
        }
        
        NEWSBLUR.Preferences[preference] = value;
        var preferences = {};
        preferences[preference] = value;
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/profile/set_preference', preferences, callback, null);
        } else {
            if (callback) callback();
        }
    },
    
    save_preferences: function(preferences, callback) {
        _.each(preferences, function(value, preference) {
            NEWSBLUR.Preferences[preference] = value;
        });
        
        this.make_request('/profile/set_preference', preferences, callback, null);
    },
    
    save_account_settings: function(settings, callback) {
        var self = this;
        this.make_request('/profile/set_account_settings', settings, function(data) {
            if (data.social_profile) {
                self.user_profile.set(data.social_profile);
            }
            callback(data);
        }, null);
    },
    
    view_setting: function(feed_id, setting, callback) {
        if (NEWSBLUR.reader.flags['feed_list_showing_starred'] && 
            setting == 'read_filter') return "starred";
        if (feed_id == "river:global" && setting == "order") return "newest";
        if (_.isUndefined(setting) || _.isString(setting)) {
            setting = setting || 'view';
            var s = setting.substr(0, 1);
            var feed = NEWSBLUR.Preferences.view_settings[feed_id+''];
            var default_setting = NEWSBLUR.Preferences['default_' + setting];
            if (setting == 'layout') default_setting = NEWSBLUR.Preferences['story_layout'];
            if (setting == 'read_filter' && _.string.contains(feed_id, 'river:')) {
                default_setting = 'unread';
            }
            return feed && feed[s] || default_setting;
        }
        
        var view_settings = _.clone(NEWSBLUR.Preferences.view_settings[feed_id+'']) || {};
        if (_.isString(view_settings)) {
            view_settings = {'view': view_settings};
        }
        var params = {'feed_id': feed_id+''};
        _.each(['view', 'order', 'read_filter', 'layout'], function(facet) {
            if (setting[facet]) {
                view_settings[facet.substr(0, 1)] = setting[facet];
                params['feed_'+facet+'_setting'] = setting[facet];
            }
        });
        
        if (!_.isEqual(NEWSBLUR.Preferences.view_settings[feed_id+''], view_settings)) {
            NEWSBLUR.Preferences.view_settings[feed_id+''] = view_settings;
            this.make_request('/profile/set_view_setting', params, callback, null);
            return true;
        }
    },
    
    clear_view_settings: function(view_setting_type, callback) {
        var pre_callback = _.bind(function(data) {
            if (data.view_settings) {
                NEWSBLUR.Preferences.view_settings = data.view_settings;
            }
            callback(data);
        }, this);
        
        this.make_request('/profile/clear_view_setting', {
            view_setting_type: view_setting_type
        }, pre_callback, null);
        
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
    
    get_features_page: function(page, callback, error_callback) {
        this.make_request('/reader/features', {'page': page}, callback, error_callback, {
            'ajax_group': 'queue',
            request_type: 'GET'
        });
    },
    
    load_recommended_feed: function(page, refresh, unmoderated, callback, error_callback) {
        this.make_request('/recommendations/load_recommended_feed', {
            'page'         : page, 
            'refresh'      : refresh,
            'unmoderated'  : unmoderated
        }, callback, error_callback, {
            'ajax_group': 'queue',
            request_type: 'GET'
        });
    },
    
    load_interactions_page: function(page, callback, error_callback) {
        this.make_request('/social/interactions', {
            'page': page,
            'format': 'html'
        }, function(data) {
            callback(data, 'interactions');
        }, error_callback, {
            'ajax_group': 'interactions',
            'request_type': 'GET'
        });
    },
    
    load_activities_page: function(page, callback, error_callback) {
        this.make_request('/profile/activities', {
            'page': page,
            'format': 'html'
        }, function(data) {
            callback(data, 'activities');
        }, error_callback, {
            'ajax_group': 'interactions',
            'request_type': 'GET'
        });
    },
    
    cancel_premium_subscription: function(callback, error_callback) {
        this.make_request('/profile/cancel_premium', {}, callback, error_callback);
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
        this.make_request('/statistics/dashboard_graphs', {}, callback, error_callback, {
            'ajax_group': 'statistics',
            request_type: 'GET'
        });
    },
    
    load_feedback_table: function(callback, error_callback) {
        this.make_request('/statistics/feedback_table', {}, callback, error_callback, {
            'ajax_group': 'queue',
            request_type: 'GET'
        });
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
    
    start_import_starred_stories_from_google_reader: function(callback) {
        this.make_request('/import/import_starred_stories_from_google_reader/', {}, callback);
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
          'reset_fetch': !!(this.feeds.get(feed_id).get('has_feed_exception') ||
                            this.feeds.get(feed_id).get('has_page_exception'))
        }, pre_callback, error_callback);
    },
        
    save_exception_change_feed_link: function(feed_id, feed_link, callback, error_callback) {
        var self = this;
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/rss_feeds/exception_change_feed_link', {
                'feed_id': feed_id,
                'feed_link': feed_link
            }, function(data) {
                // NEWSBLUR.log(['save_exception_change_feed_link pre_callback', feed_id, feed_link, data]);
                if (data.code < 0 || data.status_code != 200) {
                    return callback(data);
                }
                self.post_refresh_feeds(data, callback);
            }, error_callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
        
    save_exception_change_feed_address: function(feed_id, feed_address, callback, error_callback) {
        var self = this;
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/rss_feeds/exception_change_feed_address', {
                'feed_id': feed_id,
                'feed_address': feed_address
            }, function(data) {
                // NEWSBLUR.log(['save_exception_change_feed_address pre_callback', feed_id, feed_address, data]);
                if (data.code < 0 || data.status_code != 200) {
                    return callback(data);
                }
                self.post_refresh_feeds(data, callback);
            }, error_callback);
        } else {
            if ($.isFunction(callback)) callback();
        }
    },
    
    save_feed_chooser: function(approved_feeds, callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/save_feed_chooser', {
                'approved_feeds': approved_feeds && _.select(approved_feeds, function(f) { return f; })
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
      this.make_request('/reader/load_tutorial', data, callback, null, {
          request_type: 'GET'
      });
    },
    
    fetch_categories: function(callback, error_callback) {
        this.make_request('/categories/', null, _.bind(function(data) {
            callback(data);
        }, this), error_callback, {
            request_type: 'GET'
        });
    },
    
    subscribe_to_categories: function(categories, callback, error_callback) {
        this.make_request('/categories/subscribe', {category: categories}, _.bind(function(data) {
            callback(data);
        }, this), error_callback, {
            request_type: 'GET'
        });
    },
    
    fetch_friends: function(callback, error_callback) {
        this.make_request('/social/load_user_friends', null, _.bind(function(data) {
            this.user_profile.set(data.user_profile);
            this.social_services = data.services;
            this.follower_profiles.reset(data.follower_profiles);
            this.following_profiles.reset(data.following_profiles);
            callback(data);
        }, this), error_callback, {
            request_type: 'GET'
        });
    },
    
    fetch_follow_requests: function(callback) {
        this.make_request('/social/load_follow_requests', null, _.bind(function(data) {
            this.user_profile.set(data.user_profile);
            callback(data);
        }, this), null, {
            request_type: 'GET'
        });
    },
    
    fetch_user_profile: function(user_id, callback) {
        this.make_request('/social/profile', {
            'user_id': user_id,
            'include_activities_html': true
        }, _.bind(function(data) {
            this.add_user_profiles(data.profiles);
            callback(data);
        }, this), callback, {
            request_type: 'GET'
        });
    },
    
    search_for_feeds: function(query, callback) {
        this.make_request('/rss_feeds/feed_autocomplete', {
            'query': query,
            'format': 'full',
            'v': 2
        }, callback, callback, {
            ajax_group: 'feed',
            request_type: 'GET'
        });
    },
    
    search_for_friends: function(query, callback) {
        this.make_request('/social/find_friends', {'query': query}, callback, callback, {
            ajax_group: 'feed',
            request_type: 'GET'
        });
    },
    
    disconnect_social_service: function(service, callback) {
        this.make_request('/oauth/'+service+'_disconnect/', null, callback);
    },
    
    load_current_user_profile: function(callback) {
        this.make_request('/social/load_user_profile', null, _.bind(function(data) {
            this.user_profile.set(data.user_profile);
            callback(data);
        }, this), null, {
            request_type: 'GET'
        });
    },
    
    save_user_profile: function(data, callback) {
        this.make_request('/social/save_user_profile/', data, _.bind(function(response) {
            this.user_profile.set(response.user_profile);
            callback(response);
        }, this));
    },
    
    save_blurblog_settings: function(data, callback) {
        this.make_request('/social/save_blurblog_settings/', data, _.bind(function(response) {
            this.user_profile.set(response.user_profile);
            callback(response);
        }, this));
    },
    
    follow_user: function(user_id, callback) {
        this.make_request('/social/follow', {'user_id': user_id}, _.bind(function(data) {
            NEWSBLUR.log(["follow data", data]);
            this.user_profile.set(data.user_profile);
            var following_profile = this.following_profiles.detect(function(profile) {
                return profile.get('user_id') == data.follow_profile.user_id;
            });
            var follow_user;
            if (following_profile) {
                follow_user = following_profile.set(data.follow_profile);
            } else {
                this.following_profiles.add(data.follow_profile);
            }
            this.social_feeds.remove(data.follow_subscription);
            this.social_feeds.add(data.follow_subscription);
            callback(data);
        }, this));
    },
    
    unfollow_user: function(user_id, callback) {
        this.make_request('/social/unfollow', {'user_id': user_id}, _.bind(function(data) {
            this.user_profile.set(data.user_profile);
            this.following_profiles.remove(function(profile) {
                return profile.get('user_id') == data.unfollow_profile.user_id;
            });
            this.social_feeds.remove(data.unfollow_profile.id);
            callback(data);
        }, this));
    },
    
    approve_follower: function(user_id, callback) {
        this.make_request('/social/approve_follower', {'user_id': user_id}, _.bind(function(data) {
            callback(data);
        }, this));
    },
    
    ignore_follower: function(user_id, callback) {
        this.make_request('/social/ignore_follower', {'user_id': user_id}, _.bind(function(data) {
            callback(data);
        }, this));
    },
    
    load_public_story_comments: function(story_id, feed_id, callback) {
        this.make_request('/social/public_comments', {
            'story_id': story_id,
            'feed_id': feed_id
        }, _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            var comments = new NEWSBLUR.Collections.Comments(data.comments);
            callback(comments);
        }, this), null, {request_type: 'GET'});
    },
    
    fetch_payment_history: function(user_id, callback) {
        this.make_request('/profile/payment_history', {
            user_id: user_id
        }, callback, null, {request_type: 'GET'});
    },
    
    upgrade_premium: function(user_id, callback, error_callback) {
        this.make_request('/profile/upgrade_premium', {
            user_id: user_id
        }, callback, error_callback);
    },
    
    update_payment_history: function(user_id, callback, error_callback) {
        this.make_request('/profile/update_payment_history', {
            user_id: user_id
        }, callback, error_callback);
    },
    
    refund_premium: function(data, callback, error_callback) {
        this.make_request('/profile/refund_premium', data, callback, error_callback);
    },
    
    never_expire_premium: function(data, callback, error_callback) {
        this.make_request('/profile/never_expire_premium', data, callback, error_callback);
    },
    
    delete_saved_stories: function(timestamp, callback, error_callback) {
        var self = this;
        var pre_callback = function(data) {
            if (data.starred_counts) {
                self.starred_feeds.reset(data.starred_counts, {parse: true});
            }
            self.starred_count = data.starred_count;
            
            if (callback) callback(data);
        };

        this.make_request('/profile/delete_starred_stories', {
            timestamp: timestamp
        }, pre_callback, error_callback);
    },
    
    delete_all_sites: function(callback, error_callback) {
        this.make_request('/profile/delete_all_sites', {}, callback, error_callback);
    },
    
    follow_twitter_account: function(username, callback) {
        this.make_request('/oauth/follow_twitter_account', {'username': username}, callback);
    },
    
    unfollow_twitter_account: function(username, callback) {
        this.make_request('/oauth/unfollow_twitter_account', {'username': username}, callback);
    },
    
    fetch_original_text: function(story_id, feed_id, callback, error_callback) {
        var story = this.get_story(story_id);
        this.make_request('/rss_feeds/original_text', {
            story_id: story_id,
            feed_id: feed_id
        }, function(data) {
            story.set('original_text', data.original_text);
            callback(data);
        }, error_callback, {
            request_type: 'GET',
            ajax_group: 'statistics'
        });
    },
    
    fetch_original_story_page: function(story_hash, callback, error_callback) {
        var story = this.get_story(story_hash);
        this.make_request('/rss_feeds/original_story', {
            story_hash: story_hash
        }, function(data) {
            story.set('original_page', data.original_page);
            callback(data);
        }, error_callback, {
            request_type: 'GET',
            ajax_group: 'statistics'
        });
    },
    
    recalculate_story_scores: function(feed_id, options) {
        options = options || {};
        this.stories.each(_.bind(function(story, i) {
            if (story.get('story_feed_id') != feed_id) return;
            var intelligence = {
                author: 0,
                feed: 0,
                tags: 0,
                title: 0
            };
            
            _.each(this.classifiers[feed_id].titles, function(classifier_score, classifier_title) {
                if (intelligence.title <= 0 && 
                    story.get('story_title', '').toLowerCase().indexOf(classifier_title.toLowerCase()) != -1) {
                    intelligence.title = classifier_score;
                }
            });
            
            _.each(this.classifiers[feed_id].authors, function(classifier_score, classifier_author) {
                if (intelligence.author <= 0 &&
                    story.get('story_authors', '').indexOf(classifier_author) != -1) {
                    intelligence.author = classifier_score;
                }
            });
            
            _.each(this.classifiers[feed_id].tags, function(classifier_score, classifier_tag) {
                if (intelligence.tags <= 0 &&
                    story.get('story_tags') && _.contains(story.get('story_tags'), classifier_tag)) {
                    intelligence.tags = classifier_score;
                }
            });
            
            _.each(this.classifiers[feed_id].feeds, function(classifier_score, classifier_feed_id) {
                if (intelligence.feed <= 0 &&
                    story.get('story_feed_id') == classifier_feed_id) {
                    intelligence.feed = classifier_score;
                }
            });
            
            story.set('intelligence', intelligence, options);
        }, this));
    }

});