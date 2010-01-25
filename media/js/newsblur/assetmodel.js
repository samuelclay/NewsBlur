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
    this.stories = {};
};

NEWSBLUR.AssetModel.Reader.prototype = {
    
    init: function() {
        return;
    },
    
    make_request: function(url, data, callback, error_callback) {
        $.ajax({
            url: url,
            data: data,
            type: 'POST',
            dataType: 'json',
            complete: function(a) {
                // NEWSBLUR.log(['make_request complete', a]);
            },
            success: function(o) {
                // NEWSBLUR.log(['make_request 1', o]);
                // var log_index = o.indexOf('<div id="django_debug"');
                var data;
                
                // if (log_index != -1) { // Debug is True
                //     var log = o.substring(log_index);
                //     var raw_data = o.substring(0, log_index);
                //     data = eval('(' + raw_data + ')');
                //     if (log) {
                //         $('#django_debug').remove();
                //         $('body').append(log);
                //     }
                // } else {
                    try {
                        // NEWSBLUR.log(['make_request 2', o, data]);
                        data = eval('(' + o + ')');
                    } catch(e) {
                        data = o;   
                    }
                // }
                
                if (callback && typeof callback == 'function'){
                    callback(data);
                }
            },
            error: function(e) {
                NEWSBLUR.log(['AJAX Error', e]);
                error_callback();
            }
        });    
    },
    
    mark_story_as_read: function(story_id, feed_id, callback) {
        var self = this;
        var read = false;
        
        for (s in this.stories) {
            if (this.stories[s].id == story_id) {
                read = this.stories[s].read_status;
                this.stories[s].read_status = 1;
                break;
            }
        }
        
        if (!read && NEWSBLUR.Globals.is_authenticated) {
            this.make_request('/reader/mark_story_as_read',
                {
                    story_id: story_id,
                    feed_id: feed_id
                }, callback
            );
        } else {
            callback(read);
        }
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
        
        var pre_callback = function(folders) {
            self.folders = folders;
            callback(folders);
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
            error_callback
        );
    },
    
    load_feed_page: function(feed_id, page, callback) {
        var self = this;
        
        this.make_request('/reader/load_feed_page',
            {
                feed_id: feed_id,
                page: page
            }, callback
        );
    },
    
    get_feed: function(feed_id, callback) {
        var self = this;
        for (fld in this.folders) {
            var feeds = this.folders[fld].feeds;
            for (f in feeds) {
                if (feeds[f].id == feed_id) {
                    return feeds[f];
                }
            }
        }
        return null;
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

