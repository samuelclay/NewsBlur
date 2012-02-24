NEWSBLUR.Models.User = Backbone.Model.extend({
    
    idAttribute: 'user_id',
    
    get: function(attr) {
        var value = Backbone.Model.prototype.get.call(this, attr);
        if (attr == 'photo_url' && !value) {
            value = NEWSBLUR.Globals.MEDIA_URL + 'img/reader/default_profile_photo.png';
        }
        return value;
    }
    
});

NEWSBLUR.Collections.Users = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.User,
    
    find: function(user_id) {
        return this.detect(function(user) { return user.get('user_id') == user_id; });
    }
    
});