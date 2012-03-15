NEWSBLUR.Models.SocialSubscription = Backbone.Model.extend({
    
    initialize: function() {
        if (!this.get('page_url')) {
            this.set('page_url', '/social/page/' + this.get('user_id'));
        }
    }
    
});

NEWSBLUR.Collections.SocialSubscriptions = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.SocialSubscription
    
});