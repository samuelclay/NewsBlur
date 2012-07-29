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
        this.read_stories_river_count = 0;
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
        $.ajaxSettings.traditional = true;
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
                if (errorThrown == 'abort') {
                    return;
                }
                NEWSBLUR.log(['AJAX Error', e, textStatus, errorThrown, !!error_callback, error_callback]);
                
                if (error_callback) {
                    error_callback(e, textStatus, errorThrown);
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
    
    mark_social_story_as_read: function(story, social_feed, callback) {
        var self = this;
        var feed_id = story.get('story_feed_id');
        var social_user_id = social_feed.get('user_id');
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
        
        this.read_stories_river_count += 1;
        $.isFunction(callback) && callback(read);
    },
    
    mark_story_as_unread: function(story_id, feed_id, callback) {
        var self = this;
        var read = true;
        var story = this.get_story(story_id);
        story.set('read_status', 0);

        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/mark_story_as_unread', {
                story_id: story_id,
                feed_id: feed_id
            }, null, null, {});
        }
        
        $.isFunction(callback) && callback();
    },
    
    mark_story_as_starred: function(story_id, callback) {
        var self = this;
        this.starred_count += 1;
        var story = this.get_story(story_id);
        story.set('starred', true);
        this.make_request('/reader/mark_story_as_starred', {
            story_id: story_id,
            feed_id:  story.get('story_feed_id')
        }, callback);
    },
    
    mark_story_as_unstarred: function(story_id, callback) {
        var self = this;
        this.starred_count -= 1;
        var story = this.get_story(story_id);
        story.set('starred', false);
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
    
    mark_story_as_shared: function(story_id, feed_id, comments, source_user_id, post_to_services, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            var story = this.get_story(story_id);
            story.set(data.story);
            callback(data);
        }, this);
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/social/share_story', {
                story_id: story_id,
                feed_id: feed_id,
                comments: comments,
                source_user_id: source_user_id,
                post_to_services: post_to_services
            }, pre_callback, error_callback);
        } else {
            error_callback();
        }
    },
    
    mark_story_as_unshared: function(story_id, feed_id, callback, error_callback) {
        var pre_callback = _.bind(function(data) {
            if (data.user_profiles) {
                this.add_user_profiles(data.user_profiles);
            }
            var story = this.get_story(story_id);
            story.set(data.story);
            callback(data);
        }, this);
        
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/social/unshare_story', {
                story_id: story_id,
                feed_id: feed_id
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

            self.folders.reset(_.compact(subscriptions.folders));
            self.starred_count = subscriptions.starred_count;
            self.social_feeds.reset(subscriptions.social_feeds);
            self.user_profile.set(subscriptions.social_profile);
            self.social_services = subscriptions.social_services;
            
            if (selected) {
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
                    read_filter: this.view_setting(feed_id, 'read_filter')
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
                this.feeds.add(data.feeds);
            }
            if (data.classifiers) {
                if (_.string.include(feed_id, ':')) {
                    _.extend(this.classifiers, data.classifiers);
                } else {
                    this.classifiers[feed_id] = _.extend({}, this.defaults['classifiers'], data.classifiers);
                }
            }
            if (data.stories && !data.stories.length) {
                this.flags['no_more_stories'] = true;
            }
            
            if (data.user_profiles) {
                var profiles = _.reject(data.user_profiles, _.bind(function(profile) {
                    return profile.id in this.user_profiles._byId;
                }, this));
                this.user_profiles.add(profiles);
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
                    }, {silent: true});
                    if (this.active_feed.hasChanged()) {
                        this.active_feed.change();
                    }
                }
                this.feed_id = feed_id;
                this.starred_stories = data.starred_stories;
                this.stories.reset(data.stories, {added: data.stories.length});
            } else if (data.stories) {
                this.stories.add(data.stories, {silent: true});
                this.stories.trigger('add', {added: data.stories.length});
            }
            
            $.isFunction(callback) && callback(data, first_load);
        }
    },
    
    load_canonical_feed: function(feed_id, callback) {
        var pre_callback = _.bind(function(data) {
            this.feeds.get(data.id).set(data);
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
            self.load_feed_precallback(data, feed_id, callback, first_load);
            
            if (NEWSBLUR.reader.flags['non_premium_river_view']) {
                var visible_stories = self.stories.visible().length;
                var max_stories = NEWSBLUR.reader.constants.RIVER_STORIES_FOR_STANDARD_ACCOUNT;
                NEWSBLUR.log(["checking no more stories", visible_stories, max_stories]);
                if (visible_stories >= max_stories) {
                    self.flags['no_more_stories'] = true;
                    self.stories.trigger('no_more_stories');
                }
            }

        };
        
        this.feed_id = feed_id;

        this.make_request('/reader/river_stories', {
            feeds: feeds,
            page: page,
            order: this.view_setting(feed_id, 'order')
            // read_filter: this.view_setting(feed_id, 'read_filter')
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
            read_filter: this.view_setting(feed_id, 'read_filter')
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
    
    post_refresh_feeds: function(data, callback) {
        if (!data.feeds) return;
        
        _.each(data.feeds, _.bind(function(feed, feed_id) {
            var existing_feed = this.feeds.get(feed_id);
            if (!existing_feed) return;
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
            
            existing_feed.set(feed);
        }, this));
        
        _.each(data.social_feeds, _.bind(function(feed) {
            var social_feed = this.social_feeds.get(feed.id);
            if (!social_feed) return;
            
            social_feed.set(feed);
        }, this));
        
        callback && callback();
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
        
        if (_.string.include(feed_id, 'social:')) {
            return this.social_feeds.get(feed_id);
        } else {
            return this.feeds.get(feed_id);
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
    
    delete_feed_by_url: function(url, in_folder, callback) {
        this.make_request('/reader/delete_feed_by_url/', {
            'url': url,
            'in_folder': in_folder || ''
        }, callback, function() {
          callback({'message': NEWSBLUR.Globals.is_anonymous ? 'Please create an account. Not much to do without an account.' : 'There was a problem trying to add this site. Please try a different URL.'});
        });
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
            this.folders.reset(data.folders);
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
            this.folders.reset(data.folders);
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
        if (_.isUndefined(setting) || _.isString(setting)) {
            setting = setting || 'view';
            var s = setting.substr(0, 1);
            var feed = NEWSBLUR.Preferences.view_settings[feed_id+''];
            var default_setting = NEWSBLUR.Preferences['default_' + setting];
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
        _.each(['view', 'order', 'read_filter'], function(facet) {
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
    
    load_interactions_page: function(page, callback, error_callback) {
        this.make_request('/social/interactions', {
            'page': page,
            'format': 'html'
        }, callback, error_callback, {request_type: 'GET'});
    },
    
    load_activities_page: function(page, callback, error_callback) {
        this.make_request('/profile/activities', {
            'page': page,
            'format': 'html'
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
                self.post_refresh_feeds(data, callback);
                NEWSBLUR.reader.force_feed_refresh(feed_id, data.new_feed_id);
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
                self.post_refresh_feeds(data, callback);
                NEWSBLUR.reader.force_feed_refresh(feed_id, data.new_feed_id);
            }, error_callback);
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
      this.make_request('/reader/load_tutorial', data, callback, null, {
          request_type: 'GET'
      });
    },
    
    fetch_friends: function(callback) {
        this.make_request('/social/load_user_friends', null, _.bind(function(data) {
            this.user_profile.set(data.user_profile);
            this.follower_profiles = new NEWSBLUR.Collections.Users(data.follower_profiles);
            this.following_profiles = new NEWSBLUR.Collections.Users(data.following_profiles);
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
    
    follow_twitter_account: function(username, callback) {
        this.make_request('/oauth/follow_twitter_account', {'username': username}, callback);
    },
    
    unfollow_twitter_account: function(username, callback) {
        this.make_request('/oauth/unfollow_twitter_account', {'username': username}, callback);
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
                    story.get('story_title', '').indexOf(classifier_title) != -1) {
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