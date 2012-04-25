NEWSBLUR.Models.SocialSubscription = Backbone.Model.extend({
    
    initialize: function() {
        if (!this.get('page_url')) {
            this.set('page_url', '/social/page/' + this.get('user_id'));
        }
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
    }
    
});