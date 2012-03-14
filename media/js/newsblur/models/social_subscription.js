NEWSBLUR.Models.SocialSubscription = Backbone.Model.extend({
    
    initialize: function() {
        if (!this.get('photo_url')) {
            console.log(["this sub", this.attributes]);
            return '/social/page/' + this.get('user_id');
        }
    }
    
});

NEWSBLUR.Collections.SocialSubscriptions = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.SocialSubscription
    
});