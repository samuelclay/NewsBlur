NEWSBLUR.Models.User = Backbone.Model.extend({
    
    get: function(attr) {
        var value = Backbone.Model.prototype.get.call(this, attr);
        if (attr == 'photo_url' && !value) {
            value = NEWSBLUR.Globals.MEDIA_URL + 'img/reader/default_profile_photo.png';
        }
        return value;
    },
    
    photo_url: function(options) {
        options = options || {};
        var url = this.get('photo_url');
        if (options.size && _.string.include(url, 'graph.facebook.com')) {
            url += '?type=' + options.size;
        } else if (options.size == 'large' && _.string.include(url, 'twimg')) {
            url = url.replace(/_normal.(\w+)/, '.$1');
        }
        return url;
    },
    
    blurblog_url: function() {
        return [
            'http://',
            Inflector.sluggify(this.get('username')),
            '.',
            window.location.host.replace('www.', '')
        ].join('');
    }
    
});

NEWSBLUR.Collections.Users = Backbone.Collection.extend({
    
    model : NEWSBLUR.Models.User,
    
    find: function(user_id) {
        return this.detect(function(user) { return user.get('user_id') == user_id; });
    },
    
    comparator: function(model) {
        return -1 * model.get('shared_stories_count');
    }
    
});