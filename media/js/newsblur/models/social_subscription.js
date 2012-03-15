NEWSBLUR.Models.SocialSubscription = Backbone.Model.extend({
    
    initialize: function() {
        console.log(["init social sub", this]);
        if (!this.get('page_url')) {
            console.log(["this sub", this.attributes]);
            this.set('page_url', '/social/page/' + this.get('user_id'));
        }
    }
    
});

NEWSBLUR.Collections.SocialSubscriptions = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.SocialSubscription
    
});