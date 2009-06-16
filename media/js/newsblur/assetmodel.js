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
    },
    
    mark_story_as_read: function(story_id, callback) {
        var self = this;
        var read = false;
        
        for (s in this.stories) {
            if (this.stories[s].id == story_id) {
                read = this.stories[s].read_status;
                this.stories[s].read_status = 1;
                break;
            }
        }
        
        if (!read) {
            this.make_request('/reader/mark_story_as_read',
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
    
    load_feed: function(feed_id, callback) {
        var self = this;
        
        var pre_callback = function(stories) {
            self.stories = stories;
            callback(stories);
        };
        
        this.make_request('/reader/load_single_feed',
            {
                feed_id: feed_id
            }, pre_callback
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
    },
};