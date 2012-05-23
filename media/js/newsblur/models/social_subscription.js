NEWSBLUR.Models.SocialSubscription = Backbone.Model.extend({
    
    initialize: function() {
        if (!this.get('page_url')) {
            this.set('page_url', '/social/page/' + this.get('user_id'));
        }
        
        _.bindAll(this, 'on_change', 'on_remove');
        this.bind('change', this.on_change);
        this.bind('remove', this.on_remove);
        this.views = [];
    },

    on_change: function() {
        NEWSBLUR.log(['Social Feed Change', this.changedAttributes(), this.previousAttributes()]);
    },
    
    on_remove: function() {
        console.log(["Remove Feed", this, this.views]);
        _.each(this.views, function(view) { view.remove(); });
    },

    is_social: function() {
        return true;
    },
    
    is_feed: function() {
        return false;
    }
    
});

NEWSBLUR.Collections.SocialSubscriptions = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.SocialSubscription,
    
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
    
    deselect: function() {
        this.chain().select(function(feed) { 
            return feed.get('selected'); 
        }).each(function(feed){ 
            feed.set('selected', false); 
        });
    }
    
});