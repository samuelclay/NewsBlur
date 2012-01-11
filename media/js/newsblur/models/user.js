NEWSBLUR.Models.User = Backbone.Model.extend({
    
    idAttribute: 'user_id'
    
});

NEWSBLUR.Collections.Users = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.User,
    
    find: function(user_id) {
        return this.detect(function(user) { return user.get('user_id') == user_id; });
    }
    
});