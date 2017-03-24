NEWSBLUR.Models.SocialSubscription = Backbone.Model.extend({
    
    initialize: function() {
        if (!this.get('page_url')) {
            this.set('page_url', '/social/page/' + this.get('user_id'));
        }
        
        _.bindAll(this, 'on_change', 'on_remove', 'update_counts');
        // this.bind('change', this.on_change);
        this.bind('remove', this.on_remove);
        
        this.bind('change:ps', this.update_counts);
        this.bind('change:nt', this.update_counts);
        this.bind('change:ng', this.update_counts);
        
        this.views = [];
    },

    on_change: function() {
        NEWSBLUR.log(['Social Feed Change', this.changedAttributes(), this.previousAttributes()]);
    },
    
    on_remove: function() {
        NEWSBLUR.log(["Remove Feed", this, this.views]);
        _.each(this.views, function(view) { view.remove(); });
    },
    
    update_counts: function() {
        NEWSBLUR.assets.social_feeds.trigger('change:counts');
    },

    is_social: function() {
        return true;
    },
    
    is_feed: function() {
        return false;
    },
    
    is_starred: function() {
        return false;
    },
    
    is_search: function() {
        return false;
    },
    
    unread_counts: function() {
        return {
            ps: this.get('ps') || 0,
            nt: this.get('nt') || 0,
            ng: this.get('ng') || 0
        };
    }
    
});

NEWSBLUR.Collections.SocialSubscriptions = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.SocialSubscription,
    
    parse: function(models) {
        _.each(models, function(feed) {
            feed.selected = false;
        });
        return models;
    },
    
    comparator: function(a, b) {
        var sort_order = NEWSBLUR.reader.model.preference('feed_order');
        var title_a = a.get('feed_title') || '';
        var title_b = b.get('feed_title') || '';
        title_a = title_a.toLowerCase();
        title_b = title_b.toLowerCase();

        if (sort_order == 'MOSTUSED') {
            var opens_a = a.get('feed_opens');
            var opens_b = b.get('feed_opens');
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
    
    unread_counts: function(existing_counts) {
        existing_counts = existing_counts || {};
        var counts = this.reduce(function(counts, item) {
            var feed_counts = item.unread_counts();
            counts['ps'] += feed_counts['ps'];
            counts['nt'] += feed_counts['nt'];
            counts['ng'] += feed_counts['ng'];
            return counts;
        }, {
            ps: existing_counts['ps'] || 0,
            nt: existing_counts['nt'] || 0,
            ng: existing_counts['ng'] || 0
        });
        
        return counts;
    }
    
});