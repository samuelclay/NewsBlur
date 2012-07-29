NEWSBLUR.Views.ProfileThumb = Backbone.View.extend({
    
    className: 'NB-story-share-profile',
    
    events: {
        "click .NB-user-avatar": "open_social_profile_modal"
    },
    
    initialize: function() {
        this.model.profile_thumb_view = this;
    },
    
    render: function() {
        var $profile = $.make('div', { className: 'NB-user-avatar', title: this.model.get('username') }, [
            $.make('img', { src: this.model.get('photo_url') })
        ]).tipsy({
            delayIn: 50,
            gravity: 's',
            fade: true,
            offset: 3
        });
        
        this.$el.html($profile);

        return this;
    },
    
    open_social_profile_modal: function() {
        this.$('.NB-user-avatar').tipsy('hide');
        NEWSBLUR.reader.open_social_profile_modal(this.model.id);
    }
    
}, {
    
    create: function(user_id, options) {
        var user = NEWSBLUR.assets.user_profiles.find(user_id);
        if (!user && user_id == NEWSBLUR.Globals.user_id) {
            user = NEWSBLUR.assets.user_profile;
        }
        if (user) {
            return new NEWSBLUR.Views.ProfileThumb(_.extend({}, {model: user}, options));
        }
    }
    
});