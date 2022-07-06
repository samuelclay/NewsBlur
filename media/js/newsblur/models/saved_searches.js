NEWSBLUR.Models.SavedSearchFeed = Backbone.Model.extend({
    
    initialize: function() {
        var feed_title = NEWSBLUR.reader.feed_title(this.get('feed_id'));
        var favicon_url = this.favicon_url();
        this.set('feed_title', "\"<b>" + this.get('query') + "</b>\" in <b>" + feed_title + "</b>");
        this.set('favicon_url', favicon_url);
        this.list_view;
    },
    
    favicon_url: function() {
        var url;
        var feed_id = this.get('feed_id');
        
        if (feed_id == 'river:' || feed_id == 'river:infrequent') {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/all-stories.svg';
        } else if (_.string.startsWith(feed_id, 'river:')) {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/folder-open.svg';
        } else if (feed_id == "read") {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/indicator-unread.svg';
        } else if (feed_id == "starred") {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/saved-stories.svg';
        } else if (_.string.startsWith(feed_id, 'starred:')) {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/tag.svg';
        } else if (_.string.startsWith(feed_id, 'feed:')) {
            url = $.favicon(parseInt(feed_id.replace('feed:', ''), 10));
        } else if (_.string.startsWith(feed_id, 'social:')) {
            url = $.favicon(NEWSBLUR.assets.get_feed(feed_id));
        }
        
        if (!url) {
            url = NEWSBLUR.Globals.MEDIA_URL + 'img/icons/nouns/search.svg';
        }
        
        return url;
    },
    
    is_social: function() {
        return false;
    },
    
    is_feed: function() {
        return false;
    },
    
    is_starred: function() {
        return false;
    },
    
    is_search: function() {
        return true;
    },
    
    unread_counts: function() {
        return {
            ps: this.get('count') || 0,
            nt: 0,
            ng: 0
        };
    },
    
    tag_slug: function() {
        return Inflector.sluggify(this.get('tag') || '');
    }
    
});

NEWSBLUR.Collections.SearchesFeeds = Backbone.Collection.extend({
    
    model: NEWSBLUR.Models.SavedSearchFeed,
    
    parse: function(models) {
        _.each(models, function(feed) {
            feed.id = 'search:' + feed.feed_id + ":" + feed.query;
        });
        return models;
    },
    
    comparator: function(a, b) {
        var sort_order = NEWSBLUR.reader.model.preference('feed_order');
        var title_a = a.get('query') || '';
        var title_b = b.get('query') || '';
        title_a = title_a.toLowerCase();
        title_b = title_b.toLowerCase();

        if (sort_order == 'MOSTUSED') {
            var opens_a = a.get('count');
            var opens_b = b.get('count');
            if (opens_a > opens_b) return -1;
            if (opens_a < opens_b) return 1;
        }
        
        // if (!sort_order || sort_order == 'ALPHABETICAL')
        if (title_a > title_b)      return 1;
        else if (title_a < title_b) return -1;
        return 0;
    },
    
    selected: function() {
        return this.detect(function(feed) { return feed.get('selected'); });
    },
    
    deselect: function() {
        this.chain().select(function(feed) { 
            return feed.get('selected'); 
        }).each(function(feed){ 
            feed.set('selected', false); 
        });
    },
    
    all_searches: function() {
        return this.pluck('saved_search');
    },
    
    get_feed: function(feed_id) {
        return this.detect(function(feed) {
            return feed.get('feed_id') == feed_id;
        });
    }
    
});
