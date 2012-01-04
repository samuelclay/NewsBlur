NEWSBLUR.Models.User = Backbone.Model.extend({
    
    idAttribute: 'user_id'
    
});

NEWSBLUR.Collections.Users = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.User
    
});