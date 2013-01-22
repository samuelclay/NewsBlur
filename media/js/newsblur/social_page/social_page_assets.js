NEWSBLUR.SocialPageAssets = Backbone.Router.extend({

    initialize: function() {
        this.social_services = {
            twitter: {},
            facebook: {}
        };
        this.user_profile = new Backbone.Model(NEWSBLUR.user_social_profile);
    },

    make_request: function(url, data, callback, error_callback, options) {
        var self = this;
        var options = $.extend({
            'traditional': true
        }, options);
        var request_type = options.request_type || 'GET';

        $.ajax(_.extend({
            url: url,
            data: data,
            type: request_type,
            cache: false,
            cacheResponse: false,
            beforeSend: function() {
                $.isFunction(options['beforeSend']) && options['beforeSend']();
                return true;
            },
            success: function(o) {
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
        
    preference: function(preference, value) {
        if (typeof value == 'undefined') {
            var pref = NEWSBLUR.Preferences[preference];
            if ((/\d+/).test(pref)) return parseInt(pref, 10);
            return pref;
        }
        
        NEWSBLUR.Preferences[preference] = value;
        var preferences = {};
        preferences[preference] = value;
        this.make_request('/profile/set_preference', preferences, null, null, {
            request_type: 'POST'
        });
    },
    
    mark_story_as_shared: function(params, callback, error_callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/social/share_story', {
                story_id: params.story_id,
                feed_id: params.story_feed_id,
                comments: params.comments,
                source_user_id: params.source_user_id,
                relative_user_id: params.relative_user_id,
                post_to_services: params.post_to_services,
                format: 'html'
            }, callback, error_callback, {
                request_type: 'POST'
            });
        } else {
            error_callback();
        }
    },

    mark_story_as_unshared: function(params, callback, error_callback) {
        if (NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/social/unshare_story', {
                story_id: params.story_id,
                feed_id: params.story_feed_id,
                relative_user_id: params.relative_user_id,
                format: 'html'
            }, callback, error_callback, {
                request_type: 'POST'
            });
        } else {
            error_callback();
        }
    },
    
    save_comment_reply: function(story_id, story_feed_id, comment_user_id, reply_comments, reply_id, callback, error_callback) {
        this.make_request('/social/save_comment_reply', {
            story_id: story_id,
            story_feed_id: story_feed_id,
            comment_user_id: comment_user_id,
            reply_comments: reply_comments,
            reply_id: reply_id,
            format: 'html'
        }, callback, error_callback, {
            request_type: 'POST'
        });
    },
    
    delete_comment_reply: function(story_id, story_feed_id, comment_user_id, reply_id, callback, error_callback) {
        this.make_request('/social/remove_comment_reply', {
            story_id: story_id,
            story_feed_id: story_feed_id,
            comment_user_id: comment_user_id,
            reply_id: reply_id,
            format: 'html'
        }, callback, error_callback, {
            request_type: 'POST'
        });
    },
    
    like_comment: function(story_id, story_feed_id, comment_user_id, callback, error_callback) {
        this.make_request('/social/like_comment', {
            story_id: story_id,
            story_feed_id: story_feed_id,
            comment_user_id: comment_user_id,
            format: 'html'
        }, callback, error_callback, {
            request_type: 'POST'
        });
    },
    
    remove_like_comment: function(story_id, story_feed_id, comment_user_id, callback, error_callback) {
        this.make_request('/social/remove_like_comment', {
            story_id: story_id,
            story_feed_id: story_feed_id,
            comment_user_id: comment_user_id,
            format: 'html'
        }, callback, error_callback, {
            request_type: 'POST'
        });
    },
    
    login: function(username, password, callback, error_callback) {
        this.make_request('/api/login', {
            username: username,
            password: password
        }, callback, error_callback, {
            request_type: 'POST'
        });
    },
    
    logout: function(callback, error_callback) {
        this.make_request('/api/logout', {}, callback, error_callback, {
            request_type: 'POST'
        });
    },
    
    signup: function(username, email, password, callback, error_callback) {
        this.make_request('/api/signup', {
            username: username,
            password: password,
            email: email
        }, callback, error_callback, {
            request_type: 'POST'
        });
    },
    
    request_invite: function(email, callback, error_callback) {
        this.make_request('/social/request_invite', {
            email: email
        }, callback, error_callback, {
            request_type: 'POST'
        });
    },

    follow_user: function(user_id, callback) {
        this.make_request('/social/follow', {'user_id': user_id}, callback, callback, {
            request_type: 'POST'
        });
    },
    
    unfollow_user: function(user_id, callback) {
        this.make_request('/social/unfollow', {'user_id': user_id}, callback, callback, {
            request_type: 'POST'
        });
    }


    
});