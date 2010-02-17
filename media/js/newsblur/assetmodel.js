NEWSBLUR.AssetModel = function() {
    var _Reader = null;
    
    return {
        reader: function(){
            if(!_Reader){
                _Reader = new NEWSBLUR.AssetModel.Reader();
                _Reader.init();
            } else {
                _Reader.init();
            }
            return _Reader;
        },
        preferences: function(){
            if(!_Prefs){
                _Prefs = new NEWSBLUR.AssetModel.Preferences();
                _Prefs.init();
            } else {
                _Prefs.init();
            }
            return _Prefs;
        }    
    };
}();

NEWSBLUR.AssetModel.Reader = function() {
    this.feeds = {};
    this.folders = [];
    this.stories = {};
};

NEWSBLUR.AssetModel.Reader.prototype = {
    
    init: function() {
        this.ajax = {};
        this.ajax['queue'] = $.manageAjax.create('queue', {queue: false}); 
        this.ajax['queue_and_cancel'] = $.manageAjax.create('queue_and_cancel', {queue: 'clear', abortOld: true}); 
        return;
    },
    
    make_request: function(url, data, callback, error_callback, options) {
        var self = this;
        var options = $.extend({
            'queue': 'queue'
        }, options);

        if (options['queue'] == 'queue_and_cancel') {
            this.ajax[options['queue']].clear(true);
        }
        
        this.ajax[options['queue']].add({
            url: url,
            data: data,
            type: 'POST',
            dataType: 'json',
            complete: function(a) {
                // NEWSBLUR.log(['make_request complete', a]);
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
            this.make_request('/reader/mark_story_as_read', {
                story_id: story_id,
                feed_id: feed_id
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
    
    load_feed: function(feed_id, page, first_load, callback, error_callback) {
        var self = this;
        
        var pre_callback = function(data) {
            // NEWSBLUR.log(['pre_callback', data]);
            if (feed_id != self.feed_id) {
                self.stories = data.stories;
                self.feed_tags = data.feed_tags;
                self.feed_authors = data.feed_authors;
                self.feed_id = feed_id;
            } else {
                $.merge(self.stories, data.stories);
            }
            callback(data, first_load);
        };
        
        // NEWSBLUR.log(['load_feed', feed_id, page, first_load, callback, pre_callback]);
        this.make_request('/reader/load_single_feed',
            {
                feed_id: feed_id,
                page: page
            }, pre_callback,
            error_callback,
            {
                'queue': 'queue_and_cancel'
            }
        );
    },
    
    load_feed_page: function(feed_id, page, callback) {
        var self = this;
        
        this.make_request('/reader/load_feed_page',
            {
                feed_id: feed_id,
                page: page
            }, callback, callback,
            {
                'queue': 'queue_and_cancel'
            }
        );
    },
    
    get_feed: function(feed_id, callback) {
        var self = this;
        
        return this.feeds[feed_id];
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
        
        this.make_request('/opml_import/process', data, callback);
    },
    
    save_classifier_story: function(story_id, data, callback) {
        this.make_request('/classifier/save/story/', data, callback);
    },
    
    save_classifier_publisher: function(data, callback) {
        this.make_request('/classifier/save/publisher', data, callback);
    }
    
};



NEWSBLUR.AssetModel.Preferences = function() {
    this.feeds = {};
    this.stories = {};
};

NEWSBLUR.AssetModel.Preferences.prototype = {
    
    init: function() {
        return;
    },
    
    make_request: function(url, data, callback) {
        $.ajax({
            url: url,
            data: data,
            type: 'POST',
            success: function(o) {
                var data = eval('(' + o + ')');
                if(callback && typeof callback == 'function'){
                    callback(data);
                }
            }
        });    
    }
    
};

